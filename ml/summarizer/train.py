"""Fine-tunes T5-small to summarise product comparisons, then evaluates it on held-out pairs.

    .venv/bin/python train.py            # train (about 10-20 minutes on an M-series Mac) and evaluate
    .venv/bin/python train.py --eval     # evaluate the saved model only
"""
import argparse
import hashlib
import json
import math
import os
import random
import re
import time
from pathlib import Path

import torch
from transformers import T5ForConditionalGeneration, T5TokenizerFast

from summaries import reference

HERE = Path(__file__).parent
EXAMPLES = HERE / "data/examples.jsonl"
MODEL_DIR = HERE / ".build/t5-summarizer"
METRICS = HERE / "metrics.json"
BASE_MODEL = "google-t5/t5-small"

# Fixed lengths, shared with the Core ML conversion and the app.
MAX_INPUT_TOKENS = 256
MAX_OUTPUT_TOKENS = 96
# Training batches are padded to one fixed size: on Apple GPUs every new tensor shape compiles and keeps a
# new graph, and variable-length batches filled the machine's memory. The longest comparison is ~170 tokens.
TRAIN_INPUT_TOKENS = 192


def load_examples():
    examples = [json.loads(line) for line in EXAMPLES.read_text().splitlines() if line.strip()]
    for example in examples:
        example["target"] = reference(example)
    return examples


def split(examples):
    """Hold out 10% of product pairs (both orders of a pair stay on the same side)."""
    def bucket(example):
        pair = "|".join(sorted([example["first"], example["second"]]))
        return int(hashlib.md5(pair.encode()).hexdigest(), 16) % 10
    train = [e for e in examples if bucket(e) != 0]
    val = [e for e in examples if bucket(e) == 0 and e["variant"] == "full"]
    return train, val


def device():
    # TRAIN_DEVICE=cpu evaluates without the GPU, which uses far less memory for generation.
    wanted = os.environ.get("TRAIN_DEVICE")
    return torch.device(wanted or ("mps" if torch.backends.mps.is_available() else "cpu"))


def train(examples, tokenizer, epochs=3, batch_size=16, lr=5e-4):
    model = T5ForConditionalGeneration.from_pretrained(BASE_MODEL).to(device())
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=0.01)
    steps = epochs * math.ceil(len(examples) / batch_size)
    scheduler = torch.optim.lr_scheduler.LambdaLR(optimizer, lambda s: min(1.0, (s + 1) / 100) * max(0.0, 1 - s / steps))
    random.seed(0)
    model.train()
    step, started = 0, time.time()
    for epoch in range(epochs):
        random.shuffle(examples)
        total = 0.0
        for i in range(0, len(examples), batch_size):
            batch = examples[i:i + batch_size]
            inputs = tokenizer([e["input"] for e in batch], max_length=TRAIN_INPUT_TOKENS, truncation=True,
                               padding="max_length", return_tensors="pt").to(device())
            labels = tokenizer([e["target"] for e in batch], max_length=MAX_OUTPUT_TOKENS, truncation=True,
                               padding="max_length", return_tensors="pt").input_ids.to(device())
            labels[labels == tokenizer.pad_token_id] = -100
            loss = model(**inputs, labels=labels).loss
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            scheduler.step()
            optimizer.zero_grad()
            total += loss.item()
            step += 1
            if step % 50 == 0:
                print(f"epoch {epoch + 1} step {step}/{steps} loss {loss.item():.4f} ({time.time() - started:.0f}s)", flush=True)
        print(f"epoch {epoch + 1} mean loss {total / math.ceil(len(examples) / batch_size):.4f}", flush=True)
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(MODEL_DIR)
    tokenizer.save_pretrained(MODEL_DIR)
    return model


# ---------- evaluation ----------

def lcs(a, b):
    previous = [0] * (len(b) + 1)
    for x in a:
        current = [0]
        for j, y in enumerate(b):
            current.append(previous[j] + 1 if x == y else max(previous[j + 1], current[j]))
        previous = current
    return previous[-1]


def rouge_l(prediction, target):
    p, t = prediction.lower().split(), target.lower().split()
    if not p or not t:
        return 0.0
    common = lcs(p, t)
    if common == 0:
        return 0.0
    precision, recall = common / len(p), common / len(t)
    return 2 * precision * recall / (precision + recall)


ADVANTAGE_WORDS = {
    "a faster chip": "faster chip", "more memory": "more memory", "more storage": "more storage",
    "a higher-resolution camera": "higher-resolution", "a bigger battery": "battery", "longer battery life": "longer battery",
    "a bigger display": "display", "a lighter build": "lighter build", "5G support": "5G support",
    "active noise cancellation": "noise cancellation", "larger drivers": "drivers", "newer Bluetooth": "newer Bluetooth",
}


def claims(text, example):
    """(product, advantage) pairs a summary states: each advantage belongs to the product named before it."""
    names = {example["first"]: "first", example["second"]: "second"}
    found = set()
    for advantage, marker in ADVANTAGE_WORDS.items():
        for match in re.finditer(re.escape(marker), text):
            before = text[:match.start()]
            owner = max(names, key=lambda n: before.rfind(n))
            if before.rfind(owner) >= 0:
                found.add((names[owner], advantage))
    return found


def true_claims(example):
    return {(f["better"], f["advantage"]) for f in example["facts"] if f.get("better") in ("first", "second") and f.get("advantage")}


def unsupported_values(text, example):
    """Numbers in the summary that don't appear in the input: a hallucinated spec value."""
    return [n for n in re.findall(r"\d+(?:\.\d+)?", text) if n not in example["input"]]


def evaluate(model, tokenizer, examples, show=5):
    model.eval()
    scores, correct, stated, expected, recalled, hallucinated, wrong_names = [], 0, 0, 0, 0, 0, 0
    samples = []
    for i in range(0, len(examples), 32):
        batch = examples[i:i + 32]
        inputs = tokenizer([e["input"] for e in batch], max_length=TRAIN_INPUT_TOKENS, truncation=True,
                           padding="max_length", return_tensors="pt").to(device())
        with torch.no_grad():
            output = model.generate(**inputs, max_new_tokens=MAX_OUTPUT_TOKENS, num_beams=1, do_sample=False)
        for example, text in zip(batch, tokenizer.batch_decode(output, skip_special_tokens=True)):
            scores.append(rouge_l(text, example["target"]))
            said, truth, wanted = claims(text, example), true_claims(example), claims(example["target"], example)
            stated += len(said)
            correct += len(said & truth)
            expected += len(wanted)
            recalled += len(said & wanted)
            hallucinated += bool(unsupported_values(text, example))
            wrong_names += not (example["first"] in text or example["second"] in text) and "similar" not in text
            if len(samples) < show:
                samples.append({"input": example["input"], "reference": example["target"], "model": text})
    metrics = {
        "validation_pairs": len(examples),
        "rouge_l": round(sum(scores) / len(scores), 4),
        "claim_precision": round(correct / max(stated, 1), 4),
        "claim_recall": round(recalled / max(expected, 1), 4),
        "summaries_with_unsupported_numbers": hallucinated,
        "summaries_naming_neither_product": wrong_names,
    }
    return metrics, samples


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--eval", action="store_true", help="evaluate the saved model without training")
    args = parser.parse_args()

    examples = load_examples()
    train_set, val_set = split(examples)
    print(f"{len(train_set)} training examples, {len(val_set)} validation pairs", flush=True)

    if args.eval:
        tokenizer = T5TokenizerFast.from_pretrained(MODEL_DIR)
        model = T5ForConditionalGeneration.from_pretrained(MODEL_DIR).to(device())
    else:
        tokenizer = T5TokenizerFast.from_pretrained(BASE_MODEL)
        lengths = [len(tokenizer(e["input"]).input_ids) for e in examples]
        print(f"input tokens: max {max(lengths)}, over limit {sum(l > TRAIN_INPUT_TOKENS for l in lengths)}", flush=True)
        targets = [len(tokenizer(e["target"]).input_ids) for e in examples]
        print(f"summary tokens: max {max(targets)}, over limit {sum(t > MAX_OUTPUT_TOKENS for t in targets)}", flush=True)
        started = time.time()
        model = train(train_set, tokenizer)
        print(f"trained in {(time.time() - started) / 60:.1f} min", flush=True)

    metrics, samples = evaluate(model, tokenizer, val_set)
    METRICS.write_text(json.dumps({"metrics": metrics, "samples": samples}, indent=2))
    print(json.dumps(metrics, indent=2))
    for sample in samples[:3]:
        print("\nREF:", sample["reference"], "\nOUT:", sample["model"])


if __name__ == "__main__":
    main()
