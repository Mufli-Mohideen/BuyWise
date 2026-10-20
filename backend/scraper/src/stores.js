import { cleanText, get } from "./http.js";

const SINGER_STORE_TYPES = {
  singershops: "Singer Shop",
  mega: "Singer Mega",
  singerhomes: "Singer Homes",
  singerplus: "Singer Plus",
  dutyfree: "Singer Duty Free",
};

const toNumber = (value) => {
  const number = Number(value);
  return Number.isFinite(number) && number !== 0 ? number : null;
};

export async function scrapeAbansStores() {
  const data = await get("https://buyabans.com/contactus/get-showroom-locations", {
    json: true,
    headers: { "X-Requested-With": "XMLHttpRequest", Accept: "application/json" },
  });
  return (data.showroom_data ?? [])
    .filter((store) => store.is_display === 1)
    .map((store) => ({
      retailer: "abans",
      name: cleanText(store.showroom_name),
      storeType: "Abans Showroom",
      address: cleanText(store.street),
      city: cleanText(store.city) || null,
      latitude: toNumber(store.latitude),
      longitude: toNumber(store.longitude),
      openingHours: cleanText(store.operational_times) || null,
    }))
    .filter((store) => store.latitude !== null && store.longitude !== null);
}

// The store locator page embeds every store as a JSON object in its script.
export async function scrapeSingerStores() {
  const html = await get("https://www.singersl.com/store-locator");
  const stores = new Map();
  for (const match of html.matchAll(/\{"title":"[^{}]*?"longitude":"[^"]*"\}/g)) {
    let store;
    try {
      store = JSON.parse(match[0]);
    } catch {
      continue;
    }
    const type = SINGER_STORE_TYPES[store.category_new];
    const latitude = toNumber(store.latitude);
    const longitude = toNumber(store.longitude);
    if (!type || latitude === null || longitude === null) continue;

    stores.set(`${store.title}|${latitude}|${longitude}`, {
      retailer: "singer",
      name: cleanText(store.title),
      storeType: type,
      address: cleanText(store.address),
      city: cleanText(store.district) || null,
      latitude,
      longitude,
      openingHours: cleanText(store.openhours) || null,
    });
  }
  return [...stores.values()];
}
