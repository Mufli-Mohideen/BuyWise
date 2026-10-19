# BuyWise comparison summariser (Core ML)

The Compare screen's summary is written by a **T5-small model fine-tuned for BuyWise** and run on the iPhone with **Core ML**. The price sentence is computed in code so prices are always exact. The model describes the specification differences.

## How it works

1. **Data:** `export_products.py` reads the published catalogue from `backend/supabase/seed.sql` (130 products). `make_inputs/main.swift` builds a comparison for every pair of products in the same category. It compiles the app's own `SpecComparison.swift` and `SpecMath.swift`, so the training input is exactly what the app gives the model. Result: 7,471 examples, including copies with a spec or two removed.
2. **Reference summaries:** `summaries.py` writes a target summary for each comparison from the facts (which product has the faster chip, more storage and so on). It picks the differences that matter most per category and varies the wording, so every training sentence is true.
3. **Training:** `train.py` fine-tunes `google-t5/t5-small` (60M parameters) for 3 epochs on an M-series Mac (about 19 minutes). 10% of product pairs are held out for evaluation.
4. **Conversion:** `convert.py` exports an encoder and a decoder with coremltools, stores the weights as 8-bit, and writes `BuyWise/Resources/SummaryEncoder.mlpackage`, `SummaryDecoder.mlpackage` and `SummaryVocab.json` (about 77 MB).
5. **In the app:** `T5Summarizer.swift` tokenizes with a Swift port of T5's SentencePiece tokenizer (checked identical to Hugging Face on 2,136 texts), runs the encoder once and the decoder once per word piece (greedy decoding). `ProductSummarizer.swift` rejects any output containing a number that isn't in the specs, and falls back to a rule-based summary.

## Results (held-out product pairs)

| Model | Pairs | Claim precision | Claim recall | ROUGE-L | Summaries with invented numbers |
|---|---|---|---|---|---|
| PyTorch (after fine-tuning) | 587 | 99.3% | 99.7% | 0.908 | 0 |
| Core ML (8-bit, as shipped) | 120 | 100% | 99.8% | 0.911 | 0 |

- *Claim precision:* of the advantages the summary states ("the X has more storage"), the share that are true and credited to the right product.
- *Claim recall:* of the advantages the reference summary mentions, the share the model also mentions.

Full numbers and sample outputs are in `metrics.json`.

## Reproduce

```bash
cd ml/summarizer
python3.13 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python export_products.py
swiftc -O -o .build/make_inputs ../../BuyWise/Services/SpecMath.swift ../../BuyWise/Services/SpecComparison.swift make_inputs/main.swift
.build/make_inputs data/products.json data/examples.jsonl
.venv/bin/python train.py                 # fine-tune + evaluate
.venv/bin/python convert.py               # Core ML packages into BuyWise/Resources
.venv/bin/python evaluate_coreml.py 120   # evaluate the shipped Core ML models
```

On a 16 GB Mac, close the iOS Simulator while training. Evaluation runs on the CPU with `TRAIN_DEVICE=cpu .venv/bin/python train.py --eval`.
