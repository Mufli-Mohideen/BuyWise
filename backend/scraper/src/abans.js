import * as cheerio from "cheerio";
import { cleanText, get, parseFirstPrice, parsePrice } from "./http.js";

const LIST_ENDPOINT = "https://buyabans.com/product-list";
const AJAX_HEADERS = { "X-Requested-With": "XMLHttpRequest", Accept: "application/json" };

export const ABANS_CATEGORIES = {
  smartphones: ["mobile-phone-device/mobile-phones-/smart-mobile-phones", "apple-product/iphone"],
  laptops: ["it-product/laptops", "apple-product/macbooks"],
  headphones: ["audio/all-audio/headphones", "apple-product/airpods"],
};

async function listCategory(categoryId, log) {
  const items = [];
  for (let page = 1; page <= 40; page++) {
    const query = new URLSearchParams({
      category_id: categoryId,
      stamp_banner_id: "0",
      sort: "new_arrivals",
      is_search_list: "false",
      aging_only: "0",
      page: String(page),
    });
    const data = await get(`${LIST_ENDPOINT}?${query}`, { json: true, headers: AJAX_HEADERS });
    if (!data.html) break;

    const $ = cheerio.load(data.html);
    const found = $(".product-list-item")
      .map((_, element) => {
        const item = $(element);
        return {
          url: item.find(".product-imgage a").first().attr("href")?.trim(),
          listPrice: parseFirstPrice(item.find(".selling-price").first().text()),
        };
      })
      .get()
      .filter((item) => item.url);

    items.push(...found);
    log(`abans ${categoryId} page ${page}: +${found.length}`);
    const next = data.links?.at(-1);
    if (!found.length || !next?.url) break;
  }
  return items;
}

function parseSpecTable(specHtml) {
  if (!specHtml) return [];
  const $ = cheerio.load(specHtml);
  const specs = [];
  let group = null;
  $("tr").each((_, row) => {
    const cells = $(row)
      .find("td, th")
      .map((_, cell) => cleanText($(cell).text()))
      .get();
    let label;
    let value;
    if (cells.length >= 3) {
      group = cells[0] || group;
      [label, value] = [cells[1], cells.slice(2).join(" ")];
    } else if (cells.length === 2) {
      [label, value] = cells;
    } else {
      return;
    }
    if (label && value) specs.push({ group, label, value });
  });
  return specs;
}

function effectivePrice(item) {
  const candidates = [item.special_price, item.price, item.extra_special_price_calculated]
    .map(parsePrice)
    .filter(Boolean);
  return candidates.length ? Math.min(...candidates) : null;
}

function toListing(item, { category, url, specs, listPrice, parentTitle }) {
  return {
    retailer: "abans",
    category,
    url,
    title: cleanText(item.name) || parentTitle,
    sku: item.sku ?? null,
    modelNumber: item.model_number ?? null,
    price: effectivePrice(item),
    originalPrice: parsePrice(item.price),
    listPrice: listPrice ?? null,
    imageUrl: item.base_image_url ?? item.main_image_url ?? null,
    isPreorder: Boolean(item.is_preorder ?? item.pre_order),
    inStock: Number(item.in_stock_inventory ?? 0) > 0,
    specs,
  };
}

export async function scrapeAbansProducts(log) {
  const byUrl = new Map();
  for (const [category, categoryIds] of Object.entries(ABANS_CATEGORIES)) {
    for (const categoryId of categoryIds) {
      for (const item of await listCategory(categoryId, log)) {
        if (!byUrl.has(item.url)) byUrl.set(item.url, { ...item, category });
      }
    }
  }

  const listings = [];
  let index = 0;
  for (const { url, listPrice, category } of byUrl.values()) {
    index++;
    let html;
    try {
      html = await get(url);
    } catch (error) {
      if (!error.notFound) throw error;
      log(`abans: skipped removed product ${url}`);
      continue;
    }
    const $ = cheerio.load(html);
    const raw = $("product-component").attr(":product");
    if (!raw) {
      log(`abans: no product data on ${url}`);
      continue;
    }
    const product = JSON.parse(raw);
    const specs = parseSpecTable(product.specification);
    const variants = product.type === "configurable" ? product.variants ?? [] : [];

    if (variants.length) {
      for (const variant of variants) {
        const variantSpecs = parseSpecTable(variant.specification);
        listings.push(
          toListing(variant, {
            category,
            url,
            specs: variantSpecs.length ? variantSpecs : specs,
            listPrice: null,
            parentTitle: product.name,
          }),
        );
      }
    } else {
      listings.push(toListing(product, { category, url, specs, listPrice, parentTitle: product.name }));
    }
    if (index % 25 === 0) log(`abans product pages: ${index}/${byUrl.size}`);
  }
  return listings;
}
