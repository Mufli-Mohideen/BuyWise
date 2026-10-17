import { mkdir, writeFile } from "node:fs/promises";
import { requestCount } from "./http.js";
import { scrapeAbansProducts } from "./abans.js";
import { scrapeCelltronicsListings, scrapeCelltronicsStores } from "./celltronics.js";
import { scrapeAbansStores } from "./stores.js";

const OUT_DIR = new URL("../data/raw/", import.meta.url);
const log = (message) => console.log(`[${new Date().toISOString().slice(11, 19)}] ${message}`);

async function save(name, data) {
  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(new URL(name, OUT_DIR), JSON.stringify(data, null, 2));
  log(`saved ${name} (${Array.isArray(data) ? data.length : Object.keys(data).length} records)`);
}

const scrapedAt = new Date().toISOString();

log("Celltronics products…");
await save("celltronics-listings.json", await scrapeCelltronicsListings(log));

log("Abans products…");
await save("abans-listings.json", await scrapeAbansProducts(log));

log("Store locations…");
await save("stores.json", [...(await scrapeAbansStores()), ...(await scrapeCelltronicsStores())]);

await save("meta.json", { scrapedAt, sources: ["https://celltronics.lk", "https://buyabans.com"] });
log(`done — ${requestCount()} network requests`);
