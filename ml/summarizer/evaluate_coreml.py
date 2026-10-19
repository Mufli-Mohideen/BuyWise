"""Measures the converted Core ML models (what ships in the app) with the same checks as train.py.

    .venv/bin/python evaluate_coreml.py [number of held-out pairs, default 200]
"""
import json
import sys

import coremltools as ct
import numpy as np
from transformers import T5TokenizerFast

from convert import APP_RESOURCES, greedy
from train import METRICS, MODEL_DIR, claims, load_examples, rouge_l, split, true_claims, unsupported_values


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    tokenizer = T5TokenizerFast.from_pretrained(MODEL_DIR)
    encoder = ct.models.MLModel(str(APP_RESOURCES / "SummaryEncoder.mlpackage"))
    decoder = ct.models.MLModel(str(APP_RESOURCES / "SummaryDecoder.mlpackage"))
    encode = lambda ids, m: encoder.predict({"input_ids": ids, "attention_mask": m})["hidden_states"]
    decode = lambda o, h, m, p: decoder.predict(
        {"decoder_input_ids": o, "encoder_hidden_states": h, "encoder_attention_mask": m, "position": p})["next_token"].item()

    _, val = split(load_examples())
    report = json.loads(METRICS.read_text()) if METRICS.exists() else {}
    for key, examples in [
        ("coreml_metrics", [e for e in val if e["variant"] == "full"][:count]),
        ("coreml_upgrade_metrics", [e for e in val if e["variant"] == "upgrade"]),
    ]:
        report[key] = measure(examples, tokenizer, encode, decode)
        print(key, json.dumps(report[key], indent=2), flush=True)
    METRICS.write_text(json.dumps(report, indent=2))


def measure(examples, tokenizer, encode, decode):
    scores, correct, stated, expected, recalled, unsupported = [], 0, 0, 0, 0, 0
    for index, example in enumerate(examples, 1):
        text = greedy(encode, decode, tokenizer, example["input"])
        scores.append(rouge_l(text, example["target"]))
        said, wanted = claims(text, example), claims(example["target"], example)
        stated += len(said)
        correct += len(said & true_claims(example))
        expected += len(wanted)
        recalled += len(said & wanted)
        unsupported += bool(unsupported_values(text, example))
        if index % 50 == 0:
            print(f"{index}/{len(examples)}", flush=True)

    return {
        "validation_pairs": len(examples),
        "rouge_l": round(sum(scores) / len(scores), 4),
        "claim_precision": round(correct / max(stated, 1), 4),
        "claim_recall": round(recalled / max(expected, 1), 4),
        "summaries_with_unsupported_numbers": unsupported,
    }


if __name__ == "__main__":
    main()
