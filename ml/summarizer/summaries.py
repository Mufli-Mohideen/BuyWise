"""Reference summaries for training: written from the comparison facts, so every claim is true.

The model learns to read a spec-by-spec comparison, pick the differences that matter most for the
category and write them as one or two plain sentences, naming each product correctly.
"""
import hashlib
import re

# Which differences matter most, per category: the model learns to mention these first.
PRIORITY = {
    "smartphones": ["Chip", "Camera", "Battery", "Storage", "Memory", "Display", "Weight", "5G"],
    "laptops": ["Chip", "Memory", "Storage", "Display", "Battery", "Weight"],
    "headphones": ["Noise Cancellation", "Battery", "Driver", "Connectivity", "Weight"],
}
MAX_POINTS = 3


def _inches(value):
    match = re.match(r"\s*(\d+(?:\.\d+)?)", value or "")
    return match.group(1) if match else None


def phrase(fact, side):
    """'more storage' → 'more storage (512GB)', using the winning product's own value."""
    value = fact[side]
    advantage = fact["advantage"]
    if advantage == "a faster chip":
        return f"a faster chip ({value})"
    if advantage in ("more memory", "more storage", "a lighter build"):
        return f"{advantage} ({value})"
    if advantage == "a higher-resolution camera":
        return f"a higher-resolution {value} camera"
    if advantage == "a bigger battery":
        return f"a bigger {value} battery"
    if advantage == "longer battery life":
        return f"longer battery life ({value[0].lower() + value[1:]})"
    if advantage == "a bigger display":
        size = _inches(value)
        return f"a bigger {size}-inch display" if size else "a bigger display"
    if advantage == "larger drivers":
        return f"larger {value} drivers"
    if advantage == "newer Bluetooth":
        return f"newer {value}"
    return advantage  # "5G support", "active noise cancellation"


def join(items):
    return items[0] if len(items) == 1 else ", ".join(items[:-1]) + " and " + items[-1]


def points(example, side):
    order = PRIORITY[example["category"]]
    facts = [f for f in example["facts"] if f.get("better") == side and f.get("advantage")]
    facts.sort(key=lambda f: order.index(f["label"]) if f["label"] in order else len(order))
    return [phrase(f, side) for f in facts[:MAX_POINTS]]


def reference(example):
    a, b = example["first"], example["second"]
    pa, pb = points(example, "first"), points(example, "second")
    # A stable choice of wording per pair, so the dataset is the same on every run.
    pick = int(hashlib.md5(example["input"].encode()).hexdigest(), 16)

    if pa and pb:
        templates = [
            "The {a} has {la}, while the {b} has {lb}.",
            "The {a} offers {la}. The {b} has {lb}.",
            "The {a} comes with {la}, whereas the {b} has {lb}.",
        ]
        text = templates[pick % 3].format(a=a, b=b, la=join(pa), lb=join(pb))
    elif pa or pb:
        winner, other, items = (a, b, pa) if pa else (b, a, pb)
        templates = [
            "The {w} has {l}.",
            "Compared with the {o}, the {w} has {l}.",
            "The {w} offers {l} over the {o}.",
        ]
        text = templates[pick % 3].format(w=winner, o=other, l=join(items))
    else:
        text = "Their listed specifications are very similar."

    chip = next((f for f in example["facts"] if f["label"] == "Chip" and f.get("better") == "same"), None)
    if chip and (pa or pb):
        text += f" Both use the {chip['first']}."
    elif chip:
        text = f"Both use the {chip['first']}, and their other listed specifications are very similar."
    return text
