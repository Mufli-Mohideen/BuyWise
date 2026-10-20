// Builds supabase/seed.sql from the raw scrape: groups colour variants, matches the same product across
// Celltronics, Abans and Singer, maps specs onto the app's labels and backfills a clearly flagged demo price history.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { canonicalSpecs, escapeRegExp, formatGB, keySpec, parseTitle, productName, specsFromText } from "./normalize.js";

const RAW = new URL("../data/raw/", import.meta.url);
const OUT = new URL("../../supabase/seed.sql", import.meta.url);
const load = async (name) => JSON.parse(await readFile(new URL(name, RAW), "utf8"));

// Matching order: earlier retailers seed the product list, later ones are matched onto it.
const RETAILERS = ["celltronics", "abans", "singer"];
const raw = Object.fromEntries(await Promise.all(RETAILERS.map(async (r) => [r, await load(`${r}-listings.json`)])));
const stores = await load("stores.json");
const { scrapedAt } = await load("meta.json");

// EANs from the original prototype catalogue, attached when the same model is on sale.
const KNOWN_BARCODES = [
  [/^sony\|.*wh-?1000xm5/, "4548736132597"],
  [/^bose\|.*(qc|quietcomfort) ultra/, "0017817846714"],
  [/^jbl\|.*live 770nc/, "6925281965664"],
  [/^apple\|.*airpods max/, "0195949487870"],
];

function uuid(name) {
  const hex = createHash("sha1").update(`buywise:${name}`).digest("hex");
  const variant = ((parseInt(hex[16], 16) & 0x3) | 0x8).toString(16);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-${variant}${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

const slugify = (text) =>
  text.toLowerCase().replace(/&/g, " and ").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");

const tokens = (text) => new Set(text.split(" ").filter(Boolean));
function dice(a, b) {
  const x = tokens(a);
  const y = tokens(b);
  if (!x.size || !y.size) return 0;
  let shared = 0;
  for (const token of x) if (y.has(token)) shared++;
  return (2 * shared) / (x.size + y.size);
}

// ---------- parse + group ----------

// A retailer item code appended to the title would otherwise split colours into separate products.
const stripTrailingSku = (title, sku) => title.replace(new RegExp(`\\s*-?\\s*${escapeRegExp(sku)}\\s*$`, "i"), "");

const seen = new Set();
const listings = RETAILERS.flatMap((r) => raw[r])
  .filter((listing) => listing.price && listing.title)
  .filter((listing) => {
    const key = `${listing.retailer}|${listing.url}|${listing.sku ?? ""}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  })
  .map((listing) => {
    const title = listing.sku ? stripTrailingSku(listing.title, listing.sku) : listing.title;
    return { ...listing, parsed: parseTitle(title, listing.category), form: formFactor(listing) };
  })
  .filter(({ parsed, category }) => parsed.modelKey && (category === "headphones" || parsed.storage));

// Earbuds and over-ear headphones often share a model name ("QuietComfort"), so keep them apart when the title says.
function formFactor({ category, title }) {
  if (category !== "headphones") return "";
  if (/\b(ear ?buds?|buds|in-?ear|tws|earphones?)\b/i.test(title)) return "earbuds";
  if (/\b(headphones?|over-?ear|on-?ear)\b/i.test(title)) return "headphones";
  return "";
}

const modelId = ({ category, parsed }) =>
  category === "laptops" && parsed.codes[0] ? parsed.codes[0] : parsed.modelKey;

const groupKey = (listing) =>
  [
    listing.category,
    listing.parsed.brandKey,
    modelId(listing),
    listing.parsed.storage ?? "",
    listing.parsed.ram ?? "",
    listing.form,
  ].join("|");

function groupByKey(items) {
  const groups = new Map();
  for (const item of items) {
    const key = groupKey(item);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(item);
  }
  return [...groups.values()];
}

const head = (product) => RETAILERS.map((r) => product[r][0]).find(Boolean);
const retailersOf = (product) => RETAILERS.filter((r) => product[r].length);
const listingsOf = (product, order = RETAILERS) => order.flatMap((r) => product[r]);

// Words that mark a different model in the same line: "iPhone 18 Pro" is not "iPhone 18 Pro Max".
const TIER_WORDS = new Set("pro max plus ultra mini lite fe neo air smart prime edge fold flip foldable power turbo".split(" "));

function matchScore(product, group) {
  const a = head(product);
  const b = group[0];
  if (a.category !== b.category || a.parsed.brandKey !== b.parsed.brandKey) return 0;
  if (a.form && b.form && a.form !== b.form) return 0;
  if ((a.parsed.storage ?? 0) !== (b.parsed.storage ?? 0)) return 0;
  if (a.parsed.ram && b.parsed.ram && a.parsed.ram !== b.parsed.ram) return 0;

  if (a.category === "laptops") {
    const codesA = a.parsed.codes;
    const codesB = b.parsed.codes;
    if (codesA.some((code) => codesB.includes(code))) return 1;
    // Same base model code with a different configuration suffix.
    const sharePrefix = (x, y) => x.length >= 7 && y.length >= 7 && (x.startsWith(y.slice(0, 7)) || y.startsWith(x.slice(0, 7)));
    if (codesA.some((x) => codesB.some((y) => sharePrefix(x, y)))) return 0.9;
  }
  // Chip names ("A18 Pro", "M4 Max") are not model tiers; some retailers leave the chip out of the title.
  const tierWords = (key) => tokens(key.replace(/\b([am]\d{1,2})\s+(pro|max)\b/g, "$1"));
  const wordsA = tierWords(a.parsed.modelKey);
  const wordsB = tierWords(b.parsed.modelKey);
  const differing = [...wordsA].filter((w) => !wordsB.has(w)).concat([...wordsB].filter((w) => !wordsA.has(w)));
  if (differing.some((w) => TIER_WORDS.has(w))) return 0;
  // Each side naming a different model number ("17" vs "18", "x9c" vs "x9d") means different generations.
  const numbered = (set, other) => [...set].some((w) => /\d/.test(w) && !other.has(w));
  if (numbered(wordsA, wordsB) && numbered(wordsB, wordsA)) return 0;
  const similarity = dice(a.parsed.modelKey, b.parsed.modelKey);
  return similarity >= 0.75 ? similarity : 0;
}

// Each retailer's groups attach to the best existing product it isn't on yet, or start a new one.
const products = [];
let crossMatched = 0;
for (const retailer of RETAILERS) {
  for (const group of groupByKey(listings.filter((l) => l.retailer === retailer))) {
    let best = null;
    let bestScore = 0;
    for (const product of products) {
      if (product[retailer].length) continue;
      const score = matchScore(product, group);
      if (score > bestScore) {
        best = product;
        bestScore = score;
      }
    }
    if (best) {
      best[retailer] = group;
      crossMatched++;
    } else {
      products.push({ ...Object.fromEntries(RETAILERS.map((r) => [r, []])), [retailer]: group });
    }
  }
}

// ---------- build product rows ----------

function mergeSpecs(product) {
  const first = head(product);
  // Retailers with real spec tables first; Celltronics specs come from description text.
  const all = listingsOf(product, ["abans", "singer", "celltronics"]);
  const byLabel = new Map();
  const ram = all.map((l) => l.parsed.ram).find(Boolean) ?? null;
  const storage = first.parsed.storage ?? null;
  for (const listing of all) {
    const rawSpecs = listing.specs?.length ? listing.specs : specsFromText(listing.descriptionText);
    for (const spec of canonicalSpecs(first.category, rawSpecs, { ram, storage, title: listing.title })) {
      if (!byLabel.has(spec.label)) byLabel.set(spec.label, spec.value);
    }
  }
  return [...byLabel].map(([label, value]) => ({ label, value }));
}

// BuyWise is about comparing stores, so only products sold by at least two of them are published.
// Set to 1 to publish the full catalogue, including single-retailer products.
const MIN_RETAILERS = 2;
const published = products.filter((p) => retailersOf(p).length >= MIN_RETAILERS);

const productRows = published.map((product) => {
  const first = head(product);
  const { brand, brandKey, model, storage, ram } = first.parsed;
  const specs = mergeSpecs(product);
  const base = productName(model, brand, first.category);
  const name = first.category === "headphones" || !storage ? base : `${base} ${formatGB(storage)}`;
  const searchKey = `${brandKey}|${first.parsed.modelKey}`;
  return {
    product,
    id: null,
    name,
    brand,
    category: first.category,
    memoryGb: listingsOf(product).map((l) => l.parsed.ram).find(Boolean) ?? ram ?? null,
    storageGb: storage ?? null,
    specs,
    keySpec: keySpec(first.category, specs),
    imageUrl: listingsOf(product).map((l) => l.imageUrl).find(Boolean) ?? null,
    tagline: product.celltronics.map((l) => l.tagline).find(Boolean) ?? null,
    barcodes: KNOWN_BARCODES.filter(([pattern]) => pattern.test(searchKey)).map(([, code]) => code),
  };
});

// Same name twice (e.g. 8GB and 12GB RAM versions of one phone): add the memory to tell them apart.
const nameCounts = new Map();
for (const row of productRows) {
  const key = `${row.brand}|${row.name}`.toLowerCase();
  nameCounts.set(key, (nameCounts.get(key) ?? 0) + 1);
}
for (const row of productRows) {
  if (nameCounts.get(`${row.brand}|${row.name}`.toLowerCase()) > 1 && row.memoryGb) {
    const withoutStorage = row.name.replace(/\s+\S+$/, "");
    row.name = row.storageGb
      ? `${withoutStorage} ${row.memoryGb}GB/${formatGB(row.storageGb)}`
      : `${row.name} ${row.memoryGb}GB`;
  }
}
const slugs = new Set();
for (const row of productRows) {
  const label = row.name.startsWith(`${row.brand} `) ? row.name : `${row.brand} ${row.name}`;
  let slug = slugify(label);
  for (let n = 2; slugs.has(slug); n++) slug = `${slugify(label)}-${n}`;
  slugs.add(slug);
  row.slug = slug;
  row.id = uuid(`product:${slug}`);
}

// ---------- price history: real snapshot + flagged demo backfill ----------

function seededRandom(seed) {
  let state = parseInt(createHash("md5").update(seed).digest("hex").slice(0, 8), 16) || 1;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return ((state >>> 0) % 100000) / 100000;
  };
}

const BACKFILL_DAYS = [90, 75, 60, 45, 30, 15, 7];
const DAY_MS = 86_400_000;
const snapshot = new Date(scrapedAt);

// Older prices drift upward going back in time, the usual pattern for electronics.
function backfillRatios(seed) {
  const random = seededRandom(seed);
  const ratios = [];
  let ratio = 1;
  for (let i = BACKFILL_DAYS.length - 1; i >= 0; i--) {
    ratio *= 1 + (random() * 0.042 - 0.012);
    ratios[i] = ratio;
  }
  return ratios;
}

function roundLikeRetailer(value, reference) {
  const ending = reference % 1000;
  return Math.max(Math.round((value - ending) / 1000) * 1000 + ending, 990);
}

// ---------- SQL ----------

const q = (value) => (value === null || value === undefined ? "null" : `'${String(value).replace(/'/g, "''")}'`);
const num = (value) => (value === null || value === undefined ? "null" : String(Number(value)));
const json = (value) => `${q(JSON.stringify(value ?? []))}::jsonb`;
const textArray = (values) => (values.length ? `array[${values.map(q).join(", ")}]::text[]` : "'{}'::text[]");

function inserts(table, columns, rows, suffix = "") {
  const out = [];
  for (let i = 0; i < rows.length; i += 200) {
    const chunk = rows.slice(i, i + 200).map((row) => `  (${row.join(", ")})`).join(",\n");
    out.push(`insert into public.${table} (${columns.join(", ")}) values\n${chunk}${suffix};`);
  }
  return out.join("\n\n");
}

const productValues = productRows.map((row) => [
  q(row.id), q(row.slug), q(row.name), q(row.brand), `${q(row.category)}::public.product_category`,
  num(row.memoryGb), num(row.storageGb), q(row.keySpec), q(row.tagline), q(row.imageUrl), json(row.specs), textArray(row.barcodes),
]);

const listingValues = [];
const historyValues = [];
for (const row of productRows) {
  for (const retailer of RETAILERS) {
    const group = row.product[retailer];
    const ratios = backfillRatios(`${row.id}:${retailer}`);
    for (const listing of group) {
      const id = uuid(`listing:${listing.retailer}|${listing.url}|${listing.sku ?? ""}`);
      const originalPrice = listing.originalPrice && listing.originalPrice > listing.price ? listing.originalPrice : null;
      const rawSpecs = listing.specs?.length ? listing.specs : specsFromText(listing.descriptionText);
      listingValues.push([
        q(id), q(row.id), q(listing.retailer), q(listing.title), q(listing.url), q(listing.sku), q(listing.modelNumber ?? null),
        num(listing.price), num(originalPrice), String(Boolean(listing.inStock)), String(Boolean(listing.isPreorder)),
        q(listing.imageUrl), json(rawSpecs), q(scrapedAt),
      ]);
      if (!listing.isPreorder) {
        BACKFILL_DAYS.forEach((days, index) => {
          const recordedAt = new Date(snapshot.getTime() - days * DAY_MS).toISOString();
          historyValues.push([q(id), num(roundLikeRetailer(listing.price * ratios[index], listing.price)), q(recordedAt), q("simulated")]);
        });
      }
      historyValues.push([q(id), num(listing.price), q(scrapedAt), q("scrape")]);
    }
  }
}

const storeValues = stores.map((store) => [
  q(uuid(`store:${store.retailer}|${store.name}|${store.latitude}|${store.longitude}`)), q(store.retailer), q(store.name),
  q(store.storeType), q(store.address), q(store.city), num(store.latitude), num(store.longitude), q(store.openingHours),
]);

const upsert = (columns) =>
  `\non conflict (id) do update set ${columns.filter((c) => c !== "id").map((c) => `${c} = excluded.${c}`).join(", ")}`;

const productColumns = ["id", "slug", "name", "brand", "category", "memory_gb", "storage_gb", "key_spec", "tagline", "image_url", "specs", "barcodes"];
const listingColumns = ["id", "product_id", "retailer_id", "title", "url", "sku", "model_number", "price", "original_price", "in_stock", "is_preorder", "image_url", "raw_specs", "scraped_at"];
const idList = (values) => `array[${values.map((row) => row[0]).join(", ")}]::uuid[]`;

// A sync, not just an insert: re-running it after a new scrape updates existing rows in place (so users'
// tracked and saved products keep pointing at them), removes products that are no longer listed, and
// replaces the scraped and simulated price history. Demo price changes ('manual') are left alone.
const sql = `-- Generated by backend/scraper (npm run build-seed) from the Celltronics, Abans and Singer snapshot taken ${scrapedAt}.
-- Do not edit by hand. Price history rows marked 'simulated' are demo backfill; 'scrape' rows are real prices.

begin;

-- Price changes found by a new scrape are real, so record them as such (this also triggers price-drop alerts).
select set_config('buywise.price_source', 'scrape', true);

${inserts("products", productColumns, productValues, upsert(productColumns))}

${inserts("listings", listingColumns, listingValues, upsert(listingColumns))}

delete from public.listings where id <> all (${idList(listingValues)});
delete from public.products where id <> all (${idList(productValues)});
delete from public.price_history where source in ('scrape', 'simulated');

${inserts("price_history", ["listing_id", "price", "recorded_at", "source"], historyValues)}

delete from public.store_branches;

${inserts("store_branches", ["id", "retailer_id", "name", "store_type", "address", "city", "latitude", "longitude", "opening_hours"], storeValues)}

commit;
`;

await writeFile(OUT, sql);

const count = (category) => productRows.filter((row) => row.category === category).length;
const combos = new Map();
for (const product of products) {
  const key = retailersOf(product).join(" + ");
  combos.set(key, (combos.get(key) ?? 0) + 1);
}
console.log(`products: ${productRows.length} (smartphones ${count("smartphones")}, laptops ${count("laptops")}, headphones ${count("headphones")}), sold by ${MIN_RETAILERS}+ retailers`);
console.log(`cross-matched groups: ${crossMatched}; all products by retailer set:`);
for (const [key, n] of [...combos].sort((a, b) => b[1] - a[1])) console.log(`  ${key}: ${n}`);
console.log(`listings: ${listingValues.length}, price history rows: ${historyValues.length}, stores: ${storeValues.length}`);
console.log(`wrote ${OUT.pathname} (${(sql.length / 1024).toFixed(0)} KB)`);
