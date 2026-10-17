import { cleanText, get } from "./http.js";

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
