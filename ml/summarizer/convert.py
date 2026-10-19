"""Converts the fine-tuned T5 summariser to Core ML for the app, and checks the result matches PyTorch.

    .venv/bin/python convert.py

Writes BuyWise/Resources/SummaryEncoder.mlpackage, SummaryDecoder.mlpackage and SummaryVocab.json.
The app runs greedy decoding: encode once, then call the decoder once per output token.
"""
import json
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from coremltools.optimize.coreml import OpLinearQuantizerConfig, OptimizationConfig, linear_quantize_weights
from transformers import T5ForConditionalGeneration, T5TokenizerFast

from train import MAX_INPUT_TOKENS, MAX_OUTPUT_TOKENS, MODEL_DIR, load_examples, split

HERE = Path(__file__).parent
APP_RESOURCES = HERE.parents[1] / "BuyWise/Resources"
# Additive attention mask value. Large but finite: float32's minimum overflows to -inf once T5's position bias
# is added, and a row of -inf turns softmax into NaN.
MASKED = -1e9


class Encoder(torch.nn.Module):
    """T5's encoder layers with a mask built here, so the traced graph is plain tensor maths."""

    def __init__(self, model):
        super().__init__()
        self.stack = model.encoder

    def forward(self, input_ids, attention_mask):
        hidden = self.stack.embed_tokens(input_ids)
        mask = (1.0 - attention_mask.to(torch.float32))[:, None, None, :] * MASKED
        bias = None
        for block in self.stack.block:
            hidden, bias, _ = block(hidden, mask, bias)
        return self.stack.final_layer_norm(hidden)


class Decoder(torch.nn.Module):
    """Runs the decoder over the tokens so far and returns the most likely next token at `position`."""

    def __init__(self, model):
        super().__init__()
        self.stack = model.decoder
        self.lm_head = model.lm_head
        # T5 rescales the decoder output before the tied output projection.
        self.scale = model.config.d_model ** -0.5 if model.config.tie_word_embeddings else 1.0
        causal = torch.triu(torch.full((MAX_OUTPUT_TOKENS, MAX_OUTPUT_TOKENS), MASKED), diagonal=1)
        self.register_buffer("causal", causal[None, None], persistent=False)

    def forward(self, decoder_input_ids, encoder_hidden_states, encoder_attention_mask, position):
        hidden = self.stack.embed_tokens(decoder_input_ids)
        cross_mask = (1.0 - encoder_attention_mask.to(torch.float32))[:, None, None, :] * MASKED
        bias = cross_bias = None
        for block in self.stack.block:
            hidden, bias, cross_bias = block(hidden, self.causal, bias, encoder_hidden_states, cross_mask, cross_bias)
        hidden = self.stack.final_layer_norm(hidden)
        hidden = torch.index_select(hidden, 1, position) * self.scale
        return torch.argmax(self.lm_head(hidden), dim=-1).to(torch.int32)


def greedy(encode, decode, tokenizer, text):
    """The same loop the app runs, so PyTorch and Core ML can be compared token by token."""
    ids = tokenizer(text, max_length=MAX_INPUT_TOKENS, truncation=True).input_ids
    input_ids = np.zeros((1, MAX_INPUT_TOKENS), dtype=np.int32)
    mask = np.zeros((1, MAX_INPUT_TOKENS), dtype=np.int32)
    input_ids[0, :len(ids)] = ids
    mask[0, :len(ids)] = 1
    hidden = encode(input_ids, mask)
    output = np.zeros((1, MAX_OUTPUT_TOKENS), dtype=np.int32)  # starts with the pad token, T5's start token
    for position in range(MAX_OUTPUT_TOKENS - 1):
        token = int(decode(output, hidden, mask, np.array([position], dtype=np.int32)))
        if token == tokenizer.eos_token_id:
            break
        output[0, position + 1] = token
    return tokenizer.decode(output[0, 1:position + 1], skip_special_tokens=True)


def main():
    tokenizer = T5TokenizerFast.from_pretrained(MODEL_DIR)
    model = T5ForConditionalGeneration.from_pretrained(MODEL_DIR, attn_implementation="eager").eval().float()
    encoder, decoder = Encoder(model).eval(), Decoder(model).eval()

    input_ids = torch.zeros((1, MAX_INPUT_TOKENS), dtype=torch.int32)
    mask = torch.ones((1, MAX_INPUT_TOKENS), dtype=torch.int32)
    hidden = encoder(input_ids, mask)
    decoder_ids = torch.zeros((1, MAX_OUTPUT_TOKENS), dtype=torch.int32)
    position = torch.zeros((1,), dtype=torch.int32)

    _, val = split(load_examples())
    torch_encode = lambda ids, m: encoder(torch.tensor(ids), torch.tensor(m)).detach().numpy()
    torch_decode = lambda o, h, m, p: decoder(torch.tensor(o), torch.tensor(h), torch.tensor(m), torch.tensor(p)).item()
    for example in val[:5]:
        ids = tokenizer(example["input"], return_tensors="pt").input_ids
        with torch.no_grad():
            reference = tokenizer.decode(model.generate(ids, max_new_tokens=MAX_OUTPUT_TOKENS)[0], skip_special_tokens=True)
            ours = greedy(torch_encode, torch_decode, tokenizer, example["input"])
        assert ours == reference, f"wrapper differs from generate:\n {ours}\n {reference}"
    print("PyTorch wrappers match model.generate", flush=True)

    with torch.no_grad():
        traced_encoder = torch.jit.trace(encoder, (input_ids, mask))
        traced_decoder = torch.jit.trace(decoder, (decoder_ids, hidden, mask, position))

    # Float32 compute: T5 activations can overflow in float16. Weights are stored as 8-bit to keep the app small.
    common = dict(convert_to="mlprogram", compute_precision=ct.precision.FLOAT32, minimum_deployment_target=ct.target.iOS18)
    ml_encoder = ct.convert(
        traced_encoder,
        inputs=[ct.TensorType("input_ids", (1, MAX_INPUT_TOKENS), np.int32),
                ct.TensorType("attention_mask", (1, MAX_INPUT_TOKENS), np.int32)],
        outputs=[ct.TensorType("hidden_states", dtype=np.float32)],
        **common,
    )
    ml_decoder = ct.convert(
        traced_decoder,
        inputs=[ct.TensorType("decoder_input_ids", (1, MAX_OUTPUT_TOKENS), np.int32),
                ct.TensorType("encoder_hidden_states", tuple(hidden.shape), np.float32),
                ct.TensorType("encoder_attention_mask", (1, MAX_INPUT_TOKENS), np.int32),
                ct.TensorType("position", (1,), np.int32)],
        outputs=[ct.TensorType("next_token", dtype=np.int32)],
        **common,
    )
    quantize = OptimizationConfig(global_config=OpLinearQuantizerConfig(mode="linear_symmetric"))
    ml_encoder = linear_quantize_weights(ml_encoder, quantize)
    ml_decoder = linear_quantize_weights(ml_decoder, quantize)

    for ml_model, name, text in [
        (ml_encoder, "SummaryEncoder", "Reads a product comparison (T5-small encoder, fine-tuned for BuyWise)."),
        (ml_decoder, "SummaryDecoder", "Writes the comparison summary one token at a time (T5-small decoder, fine-tuned for BuyWise)."),
    ]:
        ml_model.short_description = text
        ml_model.author = "BuyWise"
        ml_model.license = "Apache-2.0 (T5 base weights)"
        ml_model.version = "1.0"
        APP_RESOURCES.mkdir(parents=True, exist_ok=True)
        ml_model.save(str(APP_RESOURCES / f"{name}.mlpackage"))

    # Vocabulary for the app's Swift tokenizer: [piece, score] in id order.
    vocab = json.loads(tokenizer.backend_tokenizer.to_str())["model"]["vocab"]
    (APP_RESOURCES / "SummaryVocab.json").write_text(json.dumps(vocab, ensure_ascii=False, separators=(",", ":")))

    # Check Core ML against PyTorch on held-out pairs.
    ml_encode = lambda ids, m: ml_encoder.predict({"input_ids": ids, "attention_mask": m})["hidden_states"]
    ml_decode = lambda o, h, m, p: ml_decoder.predict(
        {"decoder_input_ids": o, "encoder_hidden_states": h, "encoder_attention_mask": m, "position": p})["next_token"].item()
    same = 0
    checked = val[:40]
    for example in checked:
        with torch.no_grad():
            expected = greedy(torch_encode, torch_decode, tokenizer, example["input"])
        actual = greedy(ml_encode, ml_decode, tokenizer, example["input"])
        same += expected == actual
        if expected != actual:
            print("DIFF\n torch :", expected, "\n coreml:", actual)
    print(f"Core ML matches PyTorch on {same}/{len(checked)} held-out summaries")
    print("sample:", actual)


if __name__ == "__main__":
    main()
