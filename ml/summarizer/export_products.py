"""Exports the published catalogue (name, category, specs) from backend/supabase/seed.sql to data/products.json,
and the older devices users may own (BuyWise/MockData/UpgradeReferenceData.swift) to data/reference_products.json."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEED = ROOT / "backend/supabase/seed.sql"
OUT = Path(__file__).parent / "data/products.json"
OWNED = ROOT / "BuyWise/MockData/UpgradeReferenceData.swift"
OWNED_OUT = Path(__file__).parent / "data/reference_products.json"

ROW = re.compile(
    r"\('(?P<id>[0-9a-f-]{36})', '(?:[^']|'')*', '(?P<name>(?:[^']|'')*)', '(?P<brand>(?:[^']|'')*)', "
    r"'(?P<category>\w+)'::public\.product_category, .*?, '(?P<specs>\[(?:[^']|'')*\])'::jsonb"
)

def main():
    products_sql = SEED.read_text().split("insert into public.listings")[0]
    products = []
    for match in ROW.finditer(products_sql):
        unquote = lambda text: text.replace("''", "'")
        products.append({
            "name": unquote(match["name"]),
            "brand": unquote(match["brand"]),
            "category": match["category"],
            "specs": json.loads(unquote(match["specs"])),
        })
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(products, indent=1))
    counts = {c: sum(p["category"] == c for p in products) for c in ("smartphones", "laptops", "headphones")}
    print(f"exported {len(products)} products {counts} -> {OUT}")

    owned = []
    for block in re.findall(r"Product\((.*?)\n    \)", OWNED.read_text(), re.S):
        specs = [{"label": label, "value": value.replace('\\"', '"')}
                 for label, value in re.findall(r'Specification\("([^"]+)", "((?:[^"\\]|\\.)*)"\)', block)]
        owned.append({"name": re.search(r'name: "([^"]+)"', block)[1],
                      "category": re.search(r"category: \.(\w+)", block)[1], "specs": specs})
    OWNED_OUT.write_text(json.dumps(owned, indent=1))
    print(f"exported {len(owned)} owned devices -> {OWNED_OUT}")

if __name__ == "__main__":
    main()
