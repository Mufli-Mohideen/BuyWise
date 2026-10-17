-- Product catalogue: scraped Celltronics and Abans listings grouped into comparable products.

create extension if not exists pg_trgm with schema extensions;

create type public.product_category as enum ('smartphones', 'laptops', 'headphones');

create table public.retailers (
  id text primary key,
  name text not null,
  website text not null
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  brand text not null,
  category public.product_category not null,
  memory_gb integer,
  storage_gb integer,
  key_spec text,
  tagline text,
  image_url text,
  -- Canonical specs the app scores on: [{ "label": "Chip", "value": "A19 Pro" }, ...]
  specs jsonb not null default '[]'::jsonb,
  barcodes text[] not null default '{}',
  search_text text generated always as (lower(brand || ' ' || name)) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index products_category_idx on public.products (category);
create index products_search_trgm_idx on public.products using gin (search_text extensions.gin_trgm_ops);
create index products_barcodes_idx on public.products using gin (barcodes);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  retailer_id text not null references public.retailers (id),
  title text not null,
  url text not null,
  sku text,
  model_number text,
  price numeric(12, 2) not null check (price > 0),
  original_price numeric(12, 2),
  in_stock boolean not null default true,
  is_preorder boolean not null default false,
  image_url text,
  raw_specs jsonb not null default '[]'::jsonb,
  scraped_at timestamptz not null,
  updated_at timestamptz not null default now(),
  unique nulls not distinct (retailer_id, url, sku)
);

create index listings_product_idx on public.listings (product_id);
create index listings_url_idx on public.listings (lower(url));
create index listings_title_trgm_idx on public.listings using gin (lower(title) extensions.gin_trgm_ops);

create table public.price_history (
  id bigint generated always as identity primary key,
  listing_id uuid not null references public.listings (id) on delete cascade,
  price numeric(12, 2) not null check (price > 0),
  recorded_at timestamptz not null default now(),
  -- 'scrape' = real snapshot, 'simulated' = demo backfill, 'manual' = demo price change
  source text not null default 'manual' check (source in ('scrape', 'simulated', 'manual'))
);

create index price_history_listing_idx on public.price_history (listing_id, recorded_at);

create table public.store_branches (
  id uuid primary key default gen_random_uuid(),
  retailer_id text not null references public.retailers (id),
  name text not null,
  store_type text,
  address text,
  city text,
  latitude double precision not null,
  longitude double precision not null,
  opening_hours text
);

create index store_branches_retailer_idx on public.store_branches (retailer_id);

-- Cheapest listing per product per retailer: what the app compares side by side.
create view public.product_offers with (security_invoker = true) as
select distinct on (l.product_id, l.retailer_id)
  l.product_id,
  l.retailer_id,
  l.id as listing_id,
  l.title,
  l.url,
  l.sku,
  l.price,
  l.original_price,
  l.in_stock,
  l.is_preorder
from public.listings l
order by l.product_id, l.retailer_id, l.price asc;

-- Lowest recorded price per product per day, across all of its listings.
create view public.product_price_history with (security_invoker = true) as
select
  l.product_id,
  date_trunc('day', h.recorded_at) as day,
  min(h.price) as price
from public.price_history h
join public.listings l on l.id = h.listing_id
group by l.product_id, date_trunc('day', h.recorded_at);

-- Catalogue is public and read-only; writes happen via seed, service role or security definer functions.
alter table public.retailers enable row level security;
alter table public.products enable row level security;
alter table public.listings enable row level security;
alter table public.price_history enable row level security;
alter table public.store_branches enable row level security;

create policy "Catalogue is readable by everyone" on public.retailers for select to anon, authenticated using (true);
create policy "Catalogue is readable by everyone" on public.products for select to anon, authenticated using (true);
create policy "Catalogue is readable by everyone" on public.listings for select to anon, authenticated using (true);
create policy "Catalogue is readable by everyone" on public.price_history for select to anon, authenticated using (true);
create policy "Catalogue is readable by everyone" on public.store_branches for select to anon, authenticated using (true);

insert into public.retailers (id, name, website) values
  ('celltronics', 'Celltronics', 'celltronics.lk'),
  ('abans', 'Abans', 'buyabans.com');
