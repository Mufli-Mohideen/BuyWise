import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";

const USER_AGENT = "Mozilla/5.0 (compatible; BuyWiseCourseworkScraper/1.0)";
const DELAY_MS = 800;
const MAX_ATTEMPTS = 4;
const CACHE_DIR = new URL("../data/cache/", import.meta.url);

let lastRequestAt = 0;
let networkRequests = 0;
let freshResponses = 0;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export const requestCount = () => networkRequests;
// Responses actually downloaded this run (not served from the cache, not 404s).
export const freshCount = () => freshResponses;

// Responses are cached on disk so re-running the parser never re-hits the retailer sites.
export async function get(url, { json = false, headers = {} } = {}) {
  const key = createHash("sha1").update(url).digest("hex");
  const file = new URL(`${key}.${json ? "json" : "html"}`, CACHE_DIR);

  try {
    const cached = await readFile(file, "utf8");
    return json ? JSON.parse(cached) : cached;
  } catch {
    // Not cached yet.
  }

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const wait = lastRequestAt + DELAY_MS - Date.now();
    if (wait > 0) await sleep(wait);
    lastRequestAt = Date.now();
    networkRequests++;

    try {
      const response = await fetch(url, {
        headers: { "User-Agent": USER_AGENT, ...headers },
        signal: AbortSignal.timeout(30_000),
      });
      if (response.status === 404 || response.status === 410) {
        const gone = new Error(`${url} is no longer available (HTTP ${response.status})`);
        gone.notFound = true;
        throw gone;
      }
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const body = await response.text();
      const parsed = json ? JSON.parse(body) : body;
      await mkdir(CACHE_DIR, { recursive: true });
      await writeFile(file, body);
      freshResponses++;
      return parsed;
    } catch (error) {
      if (error.notFound) throw error;
      if (attempt === MAX_ATTEMPTS) throw new Error(`${url} failed: ${error.message}`);
      await sleep(1500 * attempt);
    }
  }
}

export function parsePrice(value) {
  const number = Number(String(value ?? "").replace(/[^0-9.]/g, ""));
  return Number.isFinite(number) && number > 0 ? Math.round(number) : null;
}

// First amount in text like "Rs 89,999 Rs 94,999 5.26% Off", where discounted cards nest the old price.
export function parseFirstPrice(value) {
  const match = String(value ?? "").match(/\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?/);
  return match ? parsePrice(match[0]) : null;
}

export const cleanText = (text) => String(text ?? "").replace(/\s+/g, " ").trim();
