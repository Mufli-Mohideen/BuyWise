"""Exports the published catalogue (name, category, specs) from backend/supabase/seed.sql to data/products.json."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEED = ROOT / "backend/supabase/seed.sql"
OUT = Path(__file__).parent / "data/products.json"

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

if __name__ == "__main__":
    main()
