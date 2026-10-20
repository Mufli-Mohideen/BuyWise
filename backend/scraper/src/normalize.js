// Turns raw retailer titles and spec tables into comparable products:
// brand + model + memory/storage, colour stripped, specs mapped onto the labels the app scores on.

const BRANDS = {
  apple: "Apple", samsung: "Samsung", xiaomi: "Xiaomi", redmi: "Xiaomi", poco: "Xiaomi", vivo: "vivo",
  oppo: "OPPO", realme: "realme", tecno: "TECNO", infinix: "Infinix", honor: "HONOR", huawei: "HUAWEI",
  google: "Google", oneplus: "OnePlus", nokia: "Nokia", motorola: "Motorola", moto: "Motorola", zte: "ZTE",
  itel: "itel", nothing: "Nothing", hp: "HP", dell: "Dell", lenovo: "Lenovo", asus: "ASUS", acer: "Acer",
  msi: "MSI", microsoft: "Microsoft", gigabyte: "GIGABYTE", sony: "Sony", jbl: "JBL", bose: "Bose",
  beats: "Beats", sennheiser: "Sennheiser", anker: "Anker", soundcore: "Anker", marshall: "Marshall",
  skullcandy: "Skullcandy", philips: "Philips", edifier: "Edifier", boat: "boAt", lg: "LG",
  panasonic: "Panasonic", singer: "Singer", havit: "Havit", baseus: "Baseus", ugreen: "UGREEN",
  hoco: "hoco", awei: "Awei", jabra: "Jabra", audiotechnica: "Audio-Technica", "audio-technica": "Audio-Technica",
  logitech: "Logitech", razer: "Razer", hyperx: "HyperX", corsair: "Corsair", steelseries: "SteelSeries",
  oppp: "OPPO", cmf: "Nothing", mibro: "Mibro", haylou: "Haylou", qcy: "QCY", soundpeats: "SoundPEATS", sharp: "Sharp",
  toshiba: "Toshiba", chuwi: "CHUWI", avita: "AVITA", infinixbook: "Infinix", tcl: "TCL", nubia: "nubia",
  blackview: "Blackview", doogee: "DOOGEE", ulefone: "Ulefone", alcatel: "Alcatel", jvc: "JVC",
  pioneer: "Pioneer", kz: "KZ", remax: "Remax", xpg: "XPG", zebronics: "Zebronics",
};

// Product-line words that imply a brand when the title leaves it out.
const IMPLIED_BRAND = {
  iphone: "apple", macbook: "apple", airpods: "apple", ipad: "apple", galaxy: "samsung", pixel: "google",
  redmi: "xiaomi", poco: "xiaomi", zenbook: "asus", vivobook: "asus", rog: "asus", tuf: "asus",
  ideapad: "lenovo", thinkpad: "lenovo", thinkbook: "lenovo", legion: "lenovo", yoga: "lenovo",
  pavilion: "hp", victus: "hp", omen: "hp", envy: "hp", elitebook: "hp", probook: "hp",
  inspiron: "dell", vostro: "dell", latitude: "dell", xps: "dell", alienware: "dell",
  aspire: "acer", nitro: "acer", swift: "acer", predator: "acer", magicbook: "honor", matebook: "huawei",
  freebuds: "huawei", buds: null,
};

const COLOR_WORDS = new Set(
  ("black white blue silver gray grey gold green pink purple red yellow orange titanium midnight starlight " +
   "glacier burgundy graphite lavender violet cream beige brown bronze copper teal mint coral navy aqua cyan " +
   "rose champagne sand olive lime peach ivory charcoal obsidian porcelain hazel peony sage desert " +
   "ultramarine sky ocean forest lunar moonlight starry pearl jade onyx phantom icy mist dusk dawn frost " +
   "cosmic stellar marble emerald sapphire ruby amber arctic polar carbon platinum gunmetal slate stone " +
   "shadow night star space moher foggy cool classic natural deep light dark matte glossy metallic " +
   "luminous twilight aurora sunset sunrise blush lilac plum wine cherry berry mocha latte coffee " +
   "turquoise indigo azure cobalt jet ink snow cloud iceberg nebula galaxy-blue titan")
    .split(" "),
);

const FILLER_WORDS = new Set(
  ("5g 4g lte smartphone phone phones mobile dual sim ds global version laptop notebook wireless headphones " +
   "headphone headset earphones earphone earbuds earbud tws true bluetooth over ear on ear in ear over-ear " +
   "on-ear in-ear noise cancelling canceling cancellation anc adaptive active with mic microphone and the " +
   "new edition gaming ultra-thin thin light series generation gen nfc ram rom storage ssd hdd emmc nvme " +
   "pcie ddr4 ddr5 lpddr5 lpddr5x lpddr4x unified memory display inch inches fhd hd uhd oled ips windows " +
   "win 11 10 home pro-office office ms student keyboard backlit bl")
    .split(" "),
);

const CPU_PATTERN =
  /\b(intel|core\s*(?:ultra|i[3579]|[3579])|i[3579][-\s]?\d|ryzen|amd|athlon|celeron|pentium|snapdragon|apple\s+m\d|m\d\s+(?:pro|max|chip)|(?:with\s+)?a1\d\s+pro|\d+(?:st|nd|rd|th)\s+gen)\b/i;

export function toGB(amount, unit) {
  const value = Number(amount);
  return unit.toLowerCase() === "tb" ? Math.round(value * 1024) : Math.round(value);
}

export const formatGB = (gb) => (gb >= 1024 && gb % 1024 === 0 ? `${gb / 1024}TB` : `${gb}GB`);

export const escapeRegExp = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const words = (text) => text.toLowerCase().replace(/&quot;|"/g, " ").split(/[^a-z0-9.+-]+/).filter(Boolean);

export function detectBrand(title) {
  const tokens = words(title);
  for (const token of tokens.slice(0, 3)) {
    const key = token.replace(/[^a-z-]/g, "");
    const brand = BRANDS[key] ?? BRANDS[key.split("-")[0]];
    if (brand) return { key: brand.toLowerCase(), name: brand };
  }
  for (const token of tokens) {
    const implied = IMPLIED_BRAND[token];
    if (implied) return { key: BRANDS[implied].toLowerCase(), name: BRANDS[implied] };
  }
  const first = title.trim().split(/\s+/)[0] ?? "Unknown";
  return { key: first.toLowerCase(), name: first };
}

// RAM and storage from titles like "(12GB / 256GB)", "6GB + 256GB", "16GB RAM | 512GB SSD", "256GB".
export function parseMemory(title, category) {
  const text = title.replace(/&quot;/g, '"');
  let ram = null;
  let storage = null;

  const pair = text.match(/(\d{1,3})\s*(?:GB)?\s*(?:RAM)?\s*[/+|,]\s*(\d{2,4}(?:\.\d)?)\s*(GB|TB)/i);
  if (pair) {
    ram = Number(pair[1]);
    storage = toGB(pair[2], pair[3]);
  }

  const ramMatch = text.match(/(\d{1,3})\s*GB\s*(?:LP)?DDR\d?X?\s*(?:RAM)?|(\d{1,3})\s*GB\s*(?:unified\s+memory|RAM)/i);
  if (ramMatch) ram = Number(ramMatch[1] ?? ramMatch[2]);

  const storageMatch = text.match(/(\d{2,4}(?:\.\d)?)\s*(GB|TB)\s*(?:M\.2\s*)?(?:PCIe\s*)?(?:NVMe\s*)?(SSD|HDD|eMMC|storage|ROM)/i);
  if (storageMatch) storage = toGB(storageMatch[1], storageMatch[2]);

  if (storage === null) {
    const sizes = [...text.matchAll(/(\d{1,4}(?:\.\d)?)\s*(GB|TB)\b/gi)].map((m) => toGB(m[1], m[2]));
    const big = sizes.filter((gb) => gb >= 32);
    if (big.length) storage = Math.max(...big);
    const small = sizes.filter((gb) => gb <= 32 && gb !== storage);
    if (ram === null && small.length && category !== "headphones") ram = Math.max(...small);
  }
  if (category === "headphones") return { ram: null, storage: null };
  return { ram, storage };
}

function stripColorSegments(title, category) {
  let text = title.replace(/&quot;/g, '"').replace(/\s+/g, " ").trim();
  if (category !== "laptops") {
    text = text.replace(/\s*\(([^()\d]*)\)\s*$/, "").replace(/\s+-\s+([^\d-]+)$/, "").trim();
  }
  const isColorSegment = (segment) => {
    const tokens = words(segment);
    return tokens.length > 0 && tokens.length <= 4 && !/\d\s*(gb|tb)/i.test(segment) && tokens.some((t) => COLOR_WORDS.has(t));
  };

  // "(Light Purple)" anywhere, then trailing " - Pearl White", ", Carbon Black" and "| Midnight" segments.
  text = text.replace(/\s*\(([^()]*)\)/g, (group, inner) => (isColorSegment(inner) ? "" : group)).trim();
  for (let changed = true; changed; ) {
    changed = false;
    const paren = text.match(/\s*\(([^()]*)\)\s*$/);
    if (paren && isColorSegment(paren[1])) {
      text = text.slice(0, paren.index).trim();
      changed = true;
      continue;
    }
    const separator = text.match(/\s*(?:\s-\s|,|\|)\s*([^,|]*?)\s*$/);
    if (separator && isColorSegment(separator[1])) {
      text = text.slice(0, separator.index).trim();
      changed = true;
    }
  }
  return text;
}

// Manufacturer model codes such as "X1504MA-BQ3851WS", "15-FD0689TU" or "UX3405CA": the most reliable
// way to tell laptops apart and to match the same laptop across retailers.
export function modelCodes(title) {
  return [
    ...new Set(
      (title.match(/\b[A-Z0-9]*\d[A-Z0-9]*(?:-[A-Z0-9]+)*\b/gi) ?? [])
        .filter((token) => /[a-z]/i.test(token) && /\d/.test(token) && token.replace(/-/g, "").length >= 6)
        .filter((token) => !/^(\d+(gb|tb|mah|mm|hz|nits|wh|w)|i[3579]-?\d+[a-z]*|\d+(st|nd|rd|th))$/i.test(token))
        .filter((token) => !/(ddr\d|lpddr|gen\d|wifi\d|usb\d|inch$)/i.test(token))
        .map((token) => token.toLowerCase().replace(/-/g, "")),
    ),
  ];
}

// The model part of a title: brand, memory, colour, CPU details and marketing words removed.
export function parseTitle(title, category) {
  const brand = detectBrand(title);
  const { ram, storage } = parseMemory(title, category);
  const codes = category === "laptops" ? modelCodes(title) : [];
  let text = stripColorSegments(title, category);

  if (category === "laptops") {
    const cut = text.search(/,|\||\s-\s/);
    const cpu = text.search(CPU_PATTERN);
    const end = [cut, cpu].filter((index) => index > 0).reduce((a, b) => Math.min(a, b), text.length);
    text = text.slice(0, end);
  }

  text = text
    .replace(/(\d+(?:\.\d)?)\s*-?\s*inch(?:es)?\b/gi, "$1")
    .replace(/\b\d{1,2}\s*(?:GB)?\s*(?:RAM)?\s*\+\s*(?=\d{2,4}\s*(?:GB|TB))/gi, " ")
    .replace(/\([^)]*\d\s*(?:GB|TB)[^)]*\)/gi, " ")
    .replace(/\d{1,4}(?:\.\d)?\s*(?:GB|TB)\b(\s*(?:RAM|ROM|SSD|HDD|storage))?/gi, " ")
    .replace(/[()[\]|+/,]/g, " ")
    .replace(/\s+-\s+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  const brandPattern = new RegExp(`^${escapeRegExp(brand.name)}\\s+`, "i");
  let display = text
    .replace(brandPattern, "")
    .replace(/^laptop\s+/i, "")
    .replace(/\b(company|official|local|agent)\s+warranty\b|\bwith\s+copilot\b|\bglobal\s+version\b/gi, " ")
    .replace(/[\s–-]+$/, "")
    .replace(/\s+/g, " ")
    .trim();
  const displayHasCode = (code) => display.toLowerCase().replace(/-/g, "").includes(code);
  if (codes.length && !codes.some(displayHasCode)) {
    display = `${display} ${title.match(new RegExp(codes[0].split("").join("-?"), "i"))?.[0] ?? codes[0].toUpperCase()}`;
  }
  // MacBooks: retailers word them differently ("Air M3 Chip 15 inch", "Air 15.3 Inch M3"), so rebuild the name
  // from line + screen size + chip. Different chip generations must never merge.
  if (brand.key === "apple" && category === "laptops") {
    const line = title.match(/macbook\s+(air|pro|neo)/i)?.[1];
    const size =
      title.match(/\b(1[3-6])(?:\.\d)?\s*-?\s*(?:inch|"|”)/i)?.[1] ??
      title.match(/\b(1[3-6])\b(?!\s*(?:gb|tb|-?core|c\b))/i)?.[1];
    const chip = title.match(/\b(M[1-9](?:\s+(?:Pro|Max))?|A1\d\s+Pro)\b/i)?.[1]
      ?.replace(/\b(pro|max)\b/gi, (w) => w[0].toUpperCase() + w.slice(1).toLowerCase())
      .replace(/^[ma]/i, (c) => c.toUpperCase());
    if (line) {
      display = ["MacBook", line[0].toUpperCase() + line.slice(1).toLowerCase(), size, chip].filter(Boolean).join(" ");
    }
  }
  // "Smart" is filler only in "smart phone"; otherwise it names a model ("Honor X9C Smart").
  const key = words(display.replace(/\bsmart\s+phones?\b/gi, " "))
    .filter((token) => !FILLER_WORDS.has(token) && token !== brand.key)
    .join(" ");

  return { brand: brand.name, brandKey: brand.key, model: display, modelKey: key, codes, ram, storage };
}

// One tidy product name whichever retailer's title it came from: "Honor 400 lite" and "HONOR 400 Lite" both
// become "HONOR 400 Lite", "Redmi Note 14 5G Genxt warranty" becomes "Redmi Note 14 5G".
const LOWERCASE_WORDS = new Set(["with", "and", "for", "of", "the"]);

export function productName(model, brand, category) {
  let name = clean(model)
    .replace(/\b(?:genxt|company|official|local|agent)?\s*warranty\b/gi, " ")
    .replace(/\bnew\b|\b20[12]\d\b/gi, " ");
  if (category === "headphones") {
    name = name.replace(/\b(?:wireless|bluetooth|true wireless|noise[- ]cancel+ing|over[- ]ear|on[- ]ear|in[- ]ear)\b/gi, " ");
    // "Tune 670NC Headphones": the model number already says what it is.
    if (/\d/.test(name)) name = name.replace(/\bhead(?:phones?|set)\b/gi, " ");
  }
  name = name
    .replace(/\s+/g, " ")
    .trim()
    .split(" ")
    .map((word) => {
      if (/^[A-Z]{4,}$/.test(word)) return word[0] + word.slice(1).toLowerCase(); // REDMI, CHOICE
      if (/^[a-z]{2,}$/.test(word) && !LOWERCASE_WORDS.has(word)) return word[0].toUpperCase() + word.slice(1); // lite
      // HONOR writes its series in lower case: X5c, X7d, X9c.
      if (brand === "HONOR" && /^[A-Z]\d+[A-Z]$/i.test(word)) return word.slice(0, -1).toUpperCase() + word.slice(-1).toLowerCase();
      return word;
    })
    .join(" ");
  // "400 256GB" means nothing on its own; numbered models carry the brand ("HONOR 400", "Xiaomi 17T").
  return /^\d/.test(name) ? `${brand} ${name}` : name;
}

// ---------- specs ----------

const firstNumber = (text) => {
  const match = String(text ?? "").match(/\d+(?:\.\d+)?/);
  return match ? Number(match[0]) : null;
};

const clean = (value) =>
  String(value ?? "")
    .replace(/\((?:R|TM)\)|®|™/gi, "")
    .replace(/\s+/g, " ")
    .trim();

function pick(specs, ...patterns) {
  for (const pattern of patterns) {
    const found = specs.find((spec) => pattern.test(spec.label) && spec.value && !/^(n\/a|-|no|none)$/i.test(spec.value));
    if (found) return found.value;
  }
  return null;
}

function mah(text) {
  const match = String(text ?? "").match(/(\d{3,5})\s*mAh/i);
  return match ? Number(match[1]) : null;
}

function hours(text) {
  const match = String(text ?? "").match(/(\d{1,3}(?:\.\d)?)\s*(?:hours|hrs?|h)\b/i);
  return match ? Number(match[1]) : null;
}

function weightText(text, unitHint) {
  const kg = String(text ?? "").match(/(\d+(?:\.\d+)?)\s*kg/i);
  if (kg) return `${Number(kg[1])} kg`;
  const grams = String(text ?? "").match(/(\d+(?:\.\d+)?)\s*g\b/i);
  if (grams) return unitHint === "kg" ? `${(Number(grams[1]) / 1000).toFixed(2)} kg` : `${Number(grams[1])}g`;
  return null;
}

const CHIP_WORDS = { snapdragon: "Snapdragon", dimensity: "Dimensity", helio: "Helio", exynos: "Exynos", unisoc: "Unisoc",
  tiger: "Tiger", tensor: "Tensor", kirin: "Kirin", gen: "Gen", elite: "Elite", ultra: "Ultra", ultimate: "Ultimate",
  extreme: "Extreme", turbo: "Turbo", pro: "Pro", max: "Max", bionic: "Bionic", apple: "Apple" };

// Known chip words get one spelling; "6s" stays lower case and other model numbers are upper case.
function chipWord(word) {
  const known = CHIP_WORDS[word.toLowerCase()];
  if (known) return known;
  if (/^\d+s$/i.test(word)) return word.toLowerCase();
  return /\d/.test(word) ? word.toUpperCase() : word;
}

// One spelling per chip: "Qualcomm SM6225 Snapdragon 685" → "Snapdragon 685", "A19 Pro chip" → "Apple A19 Pro".
// Falls back to the title when the spec doesn't name a known chip.
function chipName(text, title = "") {
  for (const source of [text, title]) {
    const found = clean(source).match(CHIP_PATTERN)?.[0];
    if (!found) continue;
    const name = found
      .replace(/-/g, " ")
      .replace(/\s+/g, " ")
      .split(" ")
      .map(chipWord)
      .join(" ");
    return /^[AM]\d/.test(name) ? `Apple ${name}` : name;
  }
  if (!text) return null;
  const fallback = clean(text)
    .replace(/\s*\([^)]*\)/g, "")
    .split(/processor|cpu|octa-?core|,/i)[0]
    .replace(/\s+/g, " ")
    .trim();
  return fallback && !/^\d+-core$/i.test(fallback) ? fallback : null;
}

const CHIP_PATTERN = new RegExp(
  [
    String.raw`snapdragon\s+(?:8\s+elite(?:\s+gen\s*\d)?|x\s+(?:elite|plus)|\d{1,3}s?\+?\s*gen\s*\d|\d{3,4}\w?)`,
    String.raw`dimensity\s+\d{3,4}\w*(?:[-\s](?:ultra|ultimate|turbo|extreme)|\+)?`,
    String.raw`helio\s+[a-z]?\d{2,3}\w*(?:[-\s](?:ultra|ultimate|extreme))?`,
    String.raw`exynos\s+\d{3,4}`,
    String.raw`tensor\s+g\d`,
    String.raw`unisoc\s+(?:tiger\s+)?[a-z]{0,2}\d{3,4}\w*`,
    String.raw`kirin\s+\d{3,4}\w*`,
    String.raw`apple\s+m\d(?:\s+(?:pro|max))?`,
    String.raw`apple\s+a\d{2}(?:\s+(?:pro|bionic))?`,
    String.raw`\bm\d(?:\s+(?:pro|max))?(?=\s+chip)`,
    String.raw`\ba\d{2}\s+(?:pro|bionic)`,
    String.raw`\ba\d{2}(?=\s+(?:\d+nm\s+)?chip)`,
    String.raw`intel\s+core\s+(?:ultra\s+\d(?:\s+\d{3}\w*)?|i\d[-\s]?\d{4,5}\w*|\d(?:\s+\d{3}\w*)?)`,
    String.raw`ryzen\s+(?:ai\s+)?\d(?:\s+\d{3,4}\w*)?`,
  ].join("|"),
  "i",
);

// Celltronics has no spec table, only marketing copy ("6.77-inch AMOLED", "5000mAh", "A20 Pro 2nm chip"),
// so pull the measurable specs out of that text, labelled like a retailer spec table.
export function specsFromText(text) {
  const t = String(text ?? "").replace(/\s+/g, " ");
  const specs = [];
  const add = (label, value) => {
    if (value) specs.push({ group: "description", label, value });
  };
  const group = (pattern) => t.match(pattern)?.[1];

  add("Chipset", t.match(CHIP_PATTERN)?.[0]);
  const megapixels = [...t.matchAll(/(\d{1,3})\s*MP\b/gi)].map((m) => Number(m[1])).filter((mp) => mp <= 300);
  if (megapixels.length) add("Main Camera - Types", `${Math.max(...megapixels)}MP`);
  const capacity = group(/(\d{3,5})\s*mAh/i);
  add("Battery Info", capacity && `${capacity} mAh`);
  const wattHours = group(/(\d{2,3}(?:\.\d)?)\s*-?\s*W\s*h\b/i);
  add("Battery", wattHours && `${wattHours} Wh`);
  const hoursMatch =
    t.match(/up to\s+(\d{1,3})\s*(?:hours|hrs)/i) ??
    t.match(/(\d{1,3})\s*(?:hours|hrs)\s+(?:of\s+)?(?:total\s+)?(?:playback|play ?time|battery|music|listening)/i);
  if (hoursMatch) {
    add("Play Time", `Up to ${hoursMatch[1]} hours`);
    add("Battery Life", `Up to ${hoursMatch[1]} hours`);
  }
  const inches = group(/(\d{1,2}(?:\.\d{1,2})?)\s*(?:-|\s)?(?:inch|”|")/i);
  add("Display Size", inches && `${inches} inches`);
  // Only weights stated as weights, so "5G" is never read as 5 grams.
  const weight = t.match(/(?:weigh(?:s|ing|t)?(?:\s+(?:of|is|just|only|about))*\s*)(\d+(?:\.\d+)?)\s*(kg|g)\b/i)
    ?? t.match(/(\d+(?:\.\d+)?)\s*(kg|g)\s+(?:weight|light)/i);
  if (weight) add("Weight", `${weight[1]} ${weight[2].toLowerCase()}`);
  add("Bluetooth", group(/bluetooth\s*(?:v|version)?\s*([456]\.\d)(?!\s*ghz)/i));
  const driver = group(/(\d{1,2}(?:\.\d)?)\s*mm\s+(?:(?:dynamic|neodymium|full-range|graphene|custom|large)\s+)?drivers?/i);
  add("Driver Unit", driver && `${driver}mm`);
  if (/\b(active noise cancell?(?:ation|ing)|\banc\b|hybrid noise cancell?(?:ation|ing))/i.test(t)) add("Noise Cancelling", "Yes");
  return specs;
}

export function canonicalSpecs(category, specs, { ram, storage, title }) {
  const out = [];
  const add = (label, value) => {
    if (value !== null && value !== undefined && String(value).trim()) out.push({ label, value: String(value).trim() });
  };

  if (category === "smartphones") {
    const size = firstNumber(pick(specs, /^display size$/i, /screen size/i, /display.*size/i, /^display$/i, /^screen$/i));
    const type = clean(pick(specs, /^display type$/i, /display.*type/i, /panel/i) ?? "")
      .replace(/^(inner|main):\s*/i, "")
      .split(/[,;]/)[0];
    add("Display", size ? `${size}"${type ? ` ${type}` : ""}` : type || null);
    add("Chip", chipName(pick(specs, /^chipset$/i, /chip/i, /processor/i, /^cpu$/i), title));
    if (ram) add("Memory", `${ram}GB`);
    if (storage) add("Storage", formatGB(storage));
    const camera = firstNumber((pick(specs, /main camera.*type/i, /rear camera/i, /main camera/i, /back camera/i, /^camera/i) ?? "").match(/\d+(?:\.\d+)?\s*MP/i)?.[0]);
    if (camera) add("Camera", `${camera}MP`);
    const batterySpec = pick(specs, /battery info/i, /^battery/i, /battery capacity/i);
    const capacity = mah(batterySpec) ?? mah(title);
    add("Battery", capacity ? `${capacity} mAh` : null);
    add("Weight", weightText(pick(specs, /^weight/i), "g"));
    const fiveG = pick(specs, /5g network/i, /^5g$/i, /network technology/i);
    const hasFiveG = (fiveG && /5g|nr\b/i.test(`${fiveG}`)) || /\b5g\b/i.test(title);
    add("5G", hasFiveG ? "Yes" : null);
  }

  if (category === "laptops") {
    add("Chip", chipName(pick(specs, /^processor$/i, /processor/i, /^cpu/i, /chip/i), title));
    const memory = pick(specs, /^memory$/i, /^ram$/i, /memory size|installed memory|ram/i);
    const memoryGb = ram || firstNumber(memory);
    add("Memory", memoryGb ? `${memoryGb}GB` : null);
    if (storage) add("Storage", `${formatGB(storage)} SSD`);
    const size = firstNumber(pick(specs, /panel size/i, /display.*size/i, /screen size/i, /^display$/i));
    const resolution = (pick(specs, /resolution/i) ?? "").match(/\b(FHD\+?|WUXGA|QHD\+?|WQXGA|2\.8K|2K|3K|4K|UHD|OLED|HD\+?|Retina|Liquid Retina)\b/i)?.[0];
    add("Display", size ? `${size}"${resolution ? ` ${resolution}` : ""}` : null);
    const graphics = clean(pick(specs, /integrated gpu/i, /^graphic/i, /gpu|graphics/i) ?? "");
    add("Graphics", graphics ? graphics.split(/[,;]/)[0] : null);
    const batterySpec = pick(specs, /^battery/i, /battery/i);
    const wh = String(batterySpec ?? "").match(/(\d{2,3}(?:\.\d)?)\s*W\s*h/i);
    const life = hours(batterySpec);
    add("Battery", wh ? `${Number(wh[1])} Wh` : life ? `Up to ${life} hours` : null);
    add("Weight", weightText(pick(specs, /^weight/i), "kg"));
    add("OS", clean(pick(specs, /operating system|^os$/i) ?? "") || null);
  }

  if (category === "headphones") {
    const type = clean(pick(specs, /wearing style/i, /^type$/i, /form factor|headphone type|design/i) ?? "");
    add("Type", type ? type.split(/[,;]/)[0] : null);
    const playTime = hours(pick(specs, /play\s*time/i, /playback/i, /battery life/i, /^battery/i, /music/i));
    add("Battery", playTime ? `Up to ${playTime} hours` : null);
    const driverMm = firstNumber((pick(specs, /driver/i) ?? "").match(/\d+(?:\.\d+)?\s*mm/i)?.[0]);
    const driver = driverMm && driverMm >= 6 ? driverMm : null;
    add("Driver", driver ? `${driver}mm` : null);
    const bluetooth = (pick(specs, /^bluetooth/i, /bluetooth version/i, /connectivity/i, /wireless/i) ?? "").match(/\b[456]\.\d\b(?!\s*ghz)/i)?.[0];
    add("Connectivity", bluetooth ? `Bluetooth ${bluetooth}` : null);
    const anc = pick(specs, /noise cancel/i, /\banc\b/i);
    let noiseCancellation = null;
    if (anc) {
      noiseCancellation = /^(yes|active|anc)/i.test(anc) || /active noise/i.test(anc) ? "Yes" : clean(anc).slice(0, 40);
    } else if (/\b(anc|noise cancel)/i.test(title)) {
      noiseCancellation = "Yes";
    }
    add("Noise Cancellation", noiseCancellation);
    add("Weight", weightText(pick(specs, /^weight/i), "g"));
  }

  return out;
}

export function keySpec(category, specs) {
  const value = (label) => specs.find((spec) => spec.label === label)?.value;
  if (category === "smartphones") return value("Chip") ?? value("Camera") ?? value("Storage") ?? null;
  if (category === "laptops") return value("Chip") ?? value("Memory") ?? null;
  return value("Battery") ?? (value("Noise Cancellation") === "Yes" ? "Active noise cancellation" : value("Type")) ?? null;
}
