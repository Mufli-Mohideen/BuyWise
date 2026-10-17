-- Triggers and RPC functions: profiles, price-drop alerts, demo price feed, product finder.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger products_set_updated_at before update on public.products
  for each row execute function public.set_updated_at();
create trigger listings_set_updated_at before update on public.listings
  for each row execute function public.set_updated_at();
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace function public.format_lkr(amount numeric)
returns text
language sql
immutable
set search_path = ''
as $$
  select 'LKR ' || to_char(round(amount), 'FM999,999,999,990');
$$;

-- Auth: every new user gets a profile row.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, avatar_url, sign_in_method)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url',
    coalesce(new.raw_app_meta_data ->> 'provider', 'email')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Tracking: confirm in the inbox (already read, so it never fires a push).
create or replace function public.handle_tracking_started()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (user_id, kind, product_id, title, message, is_read)
  select
    new.user_id,
    'tracking_started',
    new.product_id,
    'Tracking ' || p.name,
    'We''ll let you know when the price drops by ' || round(new.drop_threshold_percent)::int || '% or more.',
    true
  from public.products p
  join public.profiles pr on pr.id = new.user_id
  where p.id = new.product_id and pr.notify_tracking;
  return new;
end;
$$;

create trigger on_tracking_started
  after insert on public.tracked_products
  for each row execute function public.handle_tracking_started();

-- Price changes: record history, then alert every tracker whose drop threshold is met.
create or replace function public.handle_listing_price_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_lowest numeric;
  new_lowest numeric;
  product_name text;
  retailer_name text;
  tracker record;
  drop_percent numeric;
begin
  if new.price = old.price then
    return new;
  end if;

  insert into public.price_history (listing_id, price, source)
  values (new.id, new.price, coalesce(nullif(current_setting('buywise.price_source', true), ''), 'manual'));

  select
    min(case when l.id = new.id then old.price else l.price end),
    min(l.price)
  into old_lowest, new_lowest
  from public.listings l
  where l.product_id = new.product_id;

  if new_lowest >= old_lowest then
    return new;
  end if;

  select p.name into product_name from public.products p where p.id = new.product_id;
  select r.name into retailer_name from public.retailers r where r.id = new.retailer_id;

  for tracker in
    select t.user_id, t.previous_price, t.drop_threshold_percent
    from public.tracked_products t
    join public.profiles pr on pr.id = t.user_id
    where t.product_id = new.product_id
      and t.alerts_enabled
      and pr.notify_price_drops
  loop
    drop_percent := (tracker.previous_price - new_lowest) / tracker.previous_price * 100;
    if drop_percent >= tracker.drop_threshold_percent then
      insert into public.notifications (user_id, kind, product_id, title, message)
      values (
        tracker.user_id,
        'price_drop',
        new.product_id,
        'Price dropped on ' || product_name,
        'Now ' || public.format_lkr(new_lowest) || ' at ' || retailer_name || ', '
          || to_char(drop_percent, 'FM990.0') || '% lower. You save '
          || public.format_lkr(tracker.previous_price - new_lowest) || '.'
      );
    end if;
  end loop;

  return new;
end;
$$;

create trigger on_listing_price_change
  after update of price on public.listings
  for each row execute function public.handle_listing_price_change();

-- Demo price feed: drop a product's cheapest listing by 6–9% so the alert flow can be shown live.
-- Note: changes the shared catalogue price for every user (coursework demo only).
create or replace function public.simulate_price_drop(target_product uuid)
returns table (listing_id uuid, old_price numeric, new_price numeric)
language plpgsql
security definer
set search_path = ''
as $$
declare
  cheapest public.listings%rowtype;
  dropped numeric;
begin
  if (select auth.uid()) is null then
    raise exception 'Not signed in';
  end if;

  select * into cheapest
  from public.listings l
  where l.product_id = target_product
  order by l.price asc
  limit 1;

  if not found then
    raise exception 'Product % has no listings', target_product;
  end if;

  dropped := greatest(floor(cheapest.price * (1 - (0.06 + random() * 0.03)) / 1000) * 1000 - 10, 990);

  insert into public.tracked_products (user_id, product_id, previous_price)
  values ((select auth.uid()), target_product, cheapest.price)
  on conflict (user_id, product_id) do nothing;

  perform set_config('buywise.price_source', 'manual', true);
  update public.listings set price = dropped where id = cheapest.id;

  return query select cheapest.id, cheapest.price, dropped;
end;
$$;

-- Demo reset: restore every listing to its scraped price and drop demo price changes.
create or replace function public.reset_demo_prices()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  restored integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Not signed in';
  end if;

  with latest_scrape as (
    select distinct on (h.listing_id) h.listing_id, h.price
    from public.price_history h
    where h.source = 'scrape'
    order by h.listing_id, h.recorded_at desc
  )
  update public.listings l
  set price = s.price
  from latest_scrape s
  where s.listing_id = l.id and l.price <> s.price;

  get diagnostics restored = row_count;
  delete from public.price_history where source = 'manual';
  return restored;
end;
$$;

-- Product finder (1/3): typed names and OCR text from photos or price tags.
-- Ranks by similarity in both directions (a short query inside a product name, a product name inside long
-- OCR text) plus a bonus when the query names the product's storage, so "512GB" picks the 512GB model.
create or replace function public.search_products(
  query text,
  category_filter public.product_category default null,
  max_results integer default 30
)
returns setof public.products
language sql
stable
set search_path = ''
as $$
  with q as (
    select lower(trim(coalesce(query, ''))) as text,
           regexp_replace(lower(coalesce(query, '')), '(\d)\s+(gb|tb)', '\1\2', 'g') as compact
  ),
  scored as (
    select
      p.*,
      greatest(
        extensions.word_similarity(q.text, p.search_text),
        coalesce((select max(extensions.word_similarity(q.text, lower(l.title))) from public.listings l where l.product_id = p.id), 0)
      ) as forward,
      greatest(
        extensions.word_similarity(p.search_text, q.text),
        coalesce((select max(extensions.word_similarity(lower(l.title), q.text)) from public.listings l where l.product_id = p.id), 0)
      ) as backward,
      case
        when p.storage_gb is null then 0
        when q.compact ~ ('(^|[^0-9])' || case when p.storage_gb >= 1024 and p.storage_gb % 1024 = 0
                                              then (p.storage_gb / 1024)::text || 'tb'
                                              else p.storage_gb::text || 'gb' end || '([^a-z]|$)') then 0.3
        else 0
      end as storage_bonus
    from public.products p, q
    where category_filter is null or p.category = category_filter
  )
  select id, slug, name, brand, category, memory_gb, storage_gb, key_spec, tagline, image_url, specs, barcodes,
         search_text, created_at, updated_at
  from scored, q
  where q.text = '' or scored.search_text like '%' || q.text || '%' or greatest(scored.forward, scored.backward) > 0.45
  order by scored.forward + scored.backward + scored.storage_bonus desc, scored.name
  limit max_results;
$$;

-- Product finder (2/3): Celltronics or Abans product link. Exact listing URL first, then the URL slug.
create or replace function public.find_product_by_url(product_url text)
returns table (product_id uuid, confidence double precision, match_method text)
language plpgsql
stable
set search_path = ''
as $$
declare
  normalized text := regexp_replace(
    lower(regexp_replace(split_part(split_part(trim(product_url), '#', 1), '?', 1), '/+$', '')),
    '^https?://(www\.)?', ''
  );
  slug_words text;
begin
  return query
    select l.product_id, 1.0::double precision, 'url'::text
    from public.listings l
    where regexp_replace(lower(l.url), '^https?://(www\.)?|/+$', '', 'g') = normalized
    limit 1;
  if found then
    return;
  end if;

  slug_words := regexp_replace(regexp_replace(normalized, '^.*/', ''), '[-_]+', ' ', 'g');
  return query
    select p.id, extensions.word_similarity(slug_words, p.search_text)::double precision, 'url_slug'::text
    from public.search_products(slug_words, null, 1) p;
end;
$$;

-- Product finder (3/3): barcode. Manufacturer EAN/UPC, or the retailer item code printed on shelf tags.
create or replace function public.find_product_by_barcode(code text)
returns setof public.products
language sql
stable
set search_path = ''
as $$
  select p.*
  from public.products p
  where length(regexp_replace(code, '\D', '', 'g')) >= 8
    and regexp_replace(code, '\D', '', 'g') = any (p.barcodes)
  union
  select p.*
  from public.products p
  join public.listings l on l.product_id = p.id
  where upper(trim(code)) in (upper(l.sku), upper(l.model_number))
  limit 1;
$$;

revoke execute on function public.simulate_price_drop(uuid) from public, anon;
revoke execute on function public.reset_demo_prices() from public, anon;
grant execute on function public.simulate_price_drop(uuid) to authenticated;
grant execute on function public.reset_demo_prices() to authenticated;
