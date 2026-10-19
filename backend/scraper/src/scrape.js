import { mkdir, readFile, writeFile } from "node:fs/promises";
import { freshCount, requestCount } from "./http.js";
import { scrapeAbansProducts } from "./abans.js";
import { scrapeCelltronicsListings, scrapeCelltronicsStores } from "./celltronics.js";
import { scrapeSingerListings, scrapeSingerSpecs } from "./singer.js";
import { scrapeAbansStores, scrapeSingerStores } from "./stores.js";

const OUT_DIR = new URL("../data/raw/", import.meta.url);
const log = (message) => console.log(`[${new Date().toISOString().slice(11, 19)}] ${message}`);

async function save(name, data) {
  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(new URL(name, OUT_DIR), JSON.stringify(data, null, 2));
  log(`saved ${name} (${Array.isArray(data) ? data.length : Object.keys(data).length} records)`);
}

const startedAt = new Date().toISOString();

log("Celltronics products…");
await save("celltronics-listings.json", await scrapeCelltronicsListings(log));

log("Abans products…");
await save("abans-listings.json", await scrapeAbansProducts(log));

log("Singer products…");
const singer = await scrapeSingerListings(log);
for (const [index, listing] of singer.entries()) {
  try {
    listing.specs = await scrapeSingerSpecs(listing.url);
  } catch (error) {
    if (!error.notFound) throw error;
    listing.specs = [];
    log(`singer: no product page for ${listing.url}`);
  }
  if ((index + 1) % 25 === 0) log(`singer product pages: ${index + 1}/${singer.length}`);
}
await save("singer-listings.json", singer);

log("Store locations…");
await save("stores.json", [
  ...(await scrapeAbansStores()),
  ...(await scrapeSingerStores()),
  ...(await scrapeCelltronicsStores()),
]);

// A run served entirely from the disk cache reflects the earlier snapshot, so keep its date.
let scrapedAt = startedAt;
if (freshCount() === 0) {
  try {
    scrapedAt = JSON.parse(await readFile(new URL("meta.json", OUT_DIR), "utf8")).scrapedAt ?? startedAt;
  } catch {}
}
await save("meta.json", { scrapedAt, sources: ["https://celltronics.lk", "https://buyabans.com", "https://www.singersl.com"] });
log(`done — ${requestCount()} network requests`);
