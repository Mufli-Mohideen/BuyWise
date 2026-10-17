# BuyWise Backend

Supabase (Postgres, Auth, Storage, Realtime) plus a one-time scraper that snapshots the current Celltronics and Abans catalogues.

```
backend/
├── scraper/                 # Node script: scrape → data/raw/*.json → supabase/seed.sql
│   ├── src/scrape.js        # fetches listings, product specs and store locations (polite, cached)
│   ├── src/build-seed.js    # groups colour variants, matches products across retailers, writes seed.sql
│   ├── src/normalize.js     # title parsing (brand, model, RAM, storage) and spec mapping
│   └── data/raw/            # the scraped snapshot (committed)
└── supabase/
    ├── config.toml
    ├── migrations/          # schema, row level security, triggers and RPC functions
    └── seed.sql             # generated catalogue data
```

## What lives where

| Feature | Backend piece |
|---|---|
| Auth / onboarding | Supabase Auth (email + password, anonymous "demo user", Sign in with Apple); `profiles` row created by trigger |
| Settings / profile | `profiles` (name, appearance, shopping priority, Face ID, notification toggles); `avatars` storage bucket |
| Dashboard | `products`, `product_offers` (cheapest listing per retailer), `product_price_history`, `store_branches` |
| Push notifications | `notifications` table + Realtime; the app shows new rows as local notifications |
| Price-drop alerts | `on_listing_price_change` trigger: records history, alerts trackers whose drop threshold is met |
| Face ID | On device (LocalAuthentication); the preference is stored in `profiles` |
| Product finder | `search_products` (name / OCR text), `find_product_by_url`, `find_product_by_barcode` (EAN or retailer item code) |
| Compare | Catalogue reads; value scores are computed in the app |
| Tracked products | `tracked_products`, `saved_products`, `recently_viewed`, `search_history` |

Every user table is protected by row level security: users can only read and change their own rows. The catalogue is read-only for clients.

## Data notes

- Prices, specs, images and store locations are a **snapshot** of celltronics.lk and buyabans.com (date in `scraper/data/raw/meta.json`). There is no live scraping.
- Celltronics is read through its public WooCommerce Store API. It has no spec tables, so specs (chip, display, battery, camera, weight) are extracted from its product descriptions.
- Only the latest price point is real. Earlier price history is generated demo data and is stored with `source = 'simulated'`. The app labels the chart accordingly.
- Only products sold by **both** Celltronics and Abans are published: 103 products (76 phones, 19 MacBooks, 8 headphones), so every product has a real side-by-side price. The scrape finds about 620 more single-retailer products; set `SHARED_ONLY = false` in `scraper/src/build-seed.js` to publish them too. Matching across retailers is automatic.
- Singer was the original second retailer but was dropped: it shares only ~14 models with Abans because the two carry different brands.
- `simulate_price_drop` and `reset_demo_prices` change the shared catalogue price. They exist for demonstrating alerts.

## Deploy to a Supabase project

```bash
cd backend
supabase login
supabase link --project-ref <your-project-ref>
supabase db push --include-seed   # migrations + catalogue data
supabase config push              # auth settings (anonymous sign-in, no email confirmation)
```

Then put the project URL and anon key in `BuyWise/Backend/SupabaseConfig.swift`.

## Refresh the catalogue snapshot

```bash
cd backend/scraper
npm install
npm run scrape        # ~15 min, one request at a time; responses cached in data/cache/
npm run build-seed    # regenerates ../supabase/seed.sql
```
