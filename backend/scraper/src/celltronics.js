import * as cheerio from "cheerio";
import { cleanText, get } from "./http.js";

// Celltronics runs WooCommerce, whose public Store API returns products as JSON.
const API = "https://www.celltronics.lk/wp-json/wc/store/v1/products";
const CONTACT = "https://celltronics.lk/contact/";

const CATEGORY_RULES = [
  ["laptops", /^(macbook|laptops?|notebooks?)$/i],
  ["smartphones", /^mobile phones$/i],
  ["headphones", /^(bluetooth earbuds|earbuds|bluetooth headphones|headphones|bluetooth headsets|earphones|airpods)$/i],
];

const ACCESSORY =
  /\b(case|cover|charger|cable|protector|tempered|glass|holder|stand|adapter|sleeve|bag|skin|strap|pouch|mount|dock|hub|stylus|keyboard|mouse|tips|cushion|ear ?pads?|replacement|refurbished|used|pre-?owned)\b/i;

const htmlText = (html) => cleanText(cheerio.load(`<div>${html ?? ""}</div>`)("div").text());

function categoryOf(product) {
  if (ACCESSORY.test(product.name)) return null;
  const names = (product.categories ?? []).map((c) => cleanText(cheerio.load(`<i>${c.name}</i>`)("i").text()));
  for (const [category, pattern] of CATEGORY_RULES) {
    if (names.some((name) => pattern.test(name))) return category;
  }
  return null;
}

function price(value, minorUnit) {
  const amount = Number(value);
  return Number.isFinite(amount) && amount > 0 ? Math.round(amount / 10 ** minorUnit) : null;
}

/// First feature bullet ("48MP Fusion camera with variable aperture"), used as the product tagline.
function tagline(shortDescription) {
  const $ = cheerio.load(`<div>${shortDescription ?? ""}</div>`);
  const bullet = cleanText($("li").first().text()) || htmlText(shortDescription).split(/(?<=[.!?])\s/)[0];
  return bullet && bullet.length <= 90 ? bullet : null;
}

export async function scrapeCelltronicsListings(log) {
  const listings = [];
  for (let page = 1; page <= 40; page++) {
    const products = await get(`${API}?per_page=100&page=${page}`, { json: true });
    if (!Array.isArray(products) || !products.length) break;

    for (const product of products) {
      const category = categoryOf(product);
      if (!category) continue;
      const minor = product.prices?.currency_minor_unit ?? 0;
      const current = price(product.prices?.price, minor);
      const regular = price(product.prices?.regular_price, minor);
      if (!current) continue;

      listings.push({
        retailer: "celltronics",
        category,
        url: product.permalink,
        title: cleanText(cheerio.load(`<i>${product.name}</i>`)("i").text()),
        sku: product.sku || null,
        modelNumber: null,
        price: current,
        originalPrice: regular && regular > current ? regular : null,
        imageUrl: product.images?.[0]?.src ?? null,
        isPreorder: /pre-?order/i.test(`${product.name} ${product.stock_availability?.text ?? ""}`),
        inStock: Boolean(product.is_in_stock),
        tagline: tagline(product.short_description),
        // No spec table: specs are pulled out of the description text during normalisation.
        descriptionText: htmlText(`${product.short_description} ${product.description}`).slice(0, 6000),
        specs: [],
      });
    }
    log(`celltronics page ${page}: ${listings.length} relevant products so far`);
    if (products.length < 100) break;
  }
  return listings;
}

/// The showroom on the contact page: address and hours in the text, coordinates in the map embed.
export async function scrapeCelltronicsStores() {
  const html = await get(CONTACT);
  const $ = cheerio.load(html);
  const text = cleanText($("body").text());
  // The map iframe is lazy-loaded, so read the embed URL from the raw HTML instead of the src attribute.
  const embed = html.match(/maps\/embed\?pb=[^"' ]+/)?.[0] ?? "";
  const longitude = Number(embed.match(/!2d(-?\d+\.\d+)/)?.[1]);
  const latitude = Number(embed.match(/!3d(-?\d+\.\d+)/)?.[1]);
  const address = text.match(/Address:\s*(.+?\b\d{5})\b/i)?.[1] ?? null;
  const hours = text.match(/Monday:\s*([0-9.:]+\s*[AP]M\s*[–-]\s*[0-9.:]+\s*[AP]M)/i)?.[1] ?? null;
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [];
  return [{
    retailer: "celltronics",
    name: "Celltronics Showroom",
    storeType: "Celltronics Showroom",
    address,
    city: "Colombo 03",
    latitude,
    longitude,
    openingHours: hours ? `${hours}, Mon – Sat` : null,
  }];
}
