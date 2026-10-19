# BuyWise comparison summariser (Core ML)

The summaries on the **Compare** screen and in **Upgrade analysis** are written by a **T5-small model fine-tuned for BuyWise** and run on the iPhone with **Core ML**. Prices, upgrade cost and price trends are computed in code so they're always exact. The model describes how the two products' specifications differ.

## How it works

1. **Data:** `export_products.py` reads the published catalogue from `backend/supabase/seed.sql` (130 products) and the 5 older devices users can pick as "I own" in Upgrade analysis. `make_inputs/main.swift` builds a comparison for every pair of products in the same category, and for every owned device against each catalogue product. It compiles the app's own `SpecComparison.swift` and `SpecMath.swift`, so the training input is exactly what the app gives the model. That gives 8,901 examples, including:
   - copies with a spec or two removed;
   - copies using short names without a storage size ("Galaxy A36 5G"), so the model copies any product name exactly.

   A spec that a product doesn't list is treated as unknown, not as "No": retailer pages often leave out 5G or noise cancellation on products that have it.
2. **Reference summaries:** `summaries.py` writes a target summary for each comparison from the facts (which product has the faster chip, more storage and so on). It picks the differences that matter most per category and varies the wording, so every training sentence is true.
3. **Training:** `train.py` fine-tunes `google-t5/t5-small` (60M parameters) for 3 epochs on an M-series Mac (about 27 minutes). 10% of product pairs are held out for evaluation.
4. **Conversion:** `convert.py` exports an encoder and a decoder with coremltools, stores the weights as 8-bit, and writes `BuyWise/Resources/SummaryEncoder.mlpackage`, `SummaryDecoder.mlpackage` and `SummaryVocab.json` (about 77 MB).
5. **In the app:** `T5Summarizer.swift` tokenizes with a Swift port of T5's SentencePiece tokenizer (checked identical to Hugging Face on 2,136 texts), runs the encoder once and the decoder once per word piece (greedy decoding). Before showing a summary, `ProductSummarizer.swift` checks it:
   - every number must appear in the specs;
   - every advantage it states must be true of the product it names;
   - no advantage may be repeated.

   If any check fails, the app shows a rule-based summary instead.

## Results (held-out product pairs)

| Model | Held-out pairs | Claim precision | Claim recall | ROUGE-L | Summaries with invented numbers |
|---|---|---|---|---|---|
| PyTorch, catalogue pairs | 587 | 99.8% | 100% | 0.914 | 0 |
| PyTorch, owned device vs new (Upgrade analysis) | 25 | 100% | 100% | 0.928 | 0 |
| Core ML (8-bit, as shipped), catalogue pairs | 120 | 99.4% | 100% | 0.905 | 0 |
| Core ML (8-bit, as shipped), owned device vs new | 25 | 100% | 100% | 0.931 | 0 |

- *Claim precision:* of the advantages the summary states ("the X has more storage"), the share that are true and credited to the right product.
- *Claim recall:* of the advantages the reference summary mentions, the share the model also mentions.

Full numbers and sample outputs are in `metrics.json`.

## Reproduce

```bash
cd ml/summarizer
python3.13 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python export_products.py
swiftc -O -o .build/make_inputs ../../BuyWise/Services/SpecMath.swift ../../BuyWise/Services/SpecComparison.swift make_inputs/main.swift
.build/make_inputs data/products.json data/examples.jsonl data/reference_products.json
.venv/bin/python train.py                 # fine-tune + evaluate
.venv/bin/python convert.py               # Core ML packages into BuyWise/Resources
.venv/bin/python evaluate_coreml.py 120   # evaluate the shipped Core ML models
```

On a 16 GB Mac, close the iOS Simulator while training. Evaluation runs on the CPU with `TRAIN_DEVICE=cpu .venv/bin/python train.py --eval`.
