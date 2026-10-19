import * as cheerio from "cheerio";
import { cleanText, get, parseFirstPrice, parsePrice } from "./http.js";

const BASE = "https://www.singersl.com/products/";

export const SINGER_CATEGORIES = {
  smartphones: ["electronics/mobile-phones/smart-phone"],
  laptops: ["electronics/laptops-notebooks/laptops", "electronics/laptops-notebooks/gaming"],
  headphones: ["entertainment/home-audio-video/headphones"],
};

function parseCard($, card, category) {
  const url = card.find("a").first().attr("href")?.trim();
  if (!url) return null;
  const image = card.find("img.card-img-top");
  const cartLink = card.find(".add-to-cart-link");
  const cardText = cleanText(card.text()).toLowerCase();
  const isPreorder = cartLink.hasClass("pre-order") || cardText.includes("pre order");
  const isOutOfStock = cardText.includes("out of stock") || cardText.includes("sold out");
  // Cards show either an online cart link or a "Find in Store" link; both mean Singer sells it.
  const isSold = cartLink.length > 0 || card.find('img[title="Find in Store"]').length > 0;

  return {
    retailer: "singer",
    category,
    url,
    // The card heading is truncated with "…"; the image title holds the full product name.
    title: cleanText(image.attr("title") || image.attr("alt") || card.find(".product__name a").text()),
    sku: cleanText(card.find(".product__code").text()) || null,
    // A discounted price wraps the struck-out original, so take the first amount.
    price: parseFirstPrice(card.find(".product__price .price").first().text()),
    originalPrice: parsePrice(card.find(".product__price .strikeout").first().text()),
    imageUrl: image.attr("src") ?? null,
    isPreorder,
    inStock: isSold && !isOutOfStock && !isPreorder,
  };
}

export async function scrapeSingerListings(log) {
  const listings = new Map();

  for (const [category, paths] of Object.entries(SINGER_CATEGORIES)) {
    for (const path of paths) {
      for (let page = 1; page <= 30; page++) {
        const $ = cheerio.load(await get(`${BASE}${path}?page=${page}`));
        let added = 0;
        $(".product .productfilter").each((_, element) => {
          const listing = parseCard($, $(element), category);
          if (!listing || listings.has(listing.url)) return;
          listings.set(listing.url, listing);
          added++;
        });
        log(`singer ${path} page ${page}: +${added}`);
        if (added === 0) break;
      }
    }
  }
  return [...listings.values()];
}

export async function scrapeSingerSpecs(url) {
  const $ = cheerio.load(await get(url));
  const specs = [];
  $("#Specifications .specifications-table").each((_, table) => {
    const group = cleanText($(table).prev("h2").text()) || null;
    $(table)
      .find("tr")
      .each((_, row) => {
        const label = cleanText($(row).find(".spec-key").text());
        const value = cleanText($(row).find(".spec-value").text());
        if (label && value) specs.push({ group, label, value });
      });
  });
  return specs;
}
