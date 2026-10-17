-- Per-user data. Every table is locked to its owner with row level security.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  avatar_url text,
  sign_in_method text not null default 'email',
  appearance_mode text not null default 'light' check (appearance_mode in ('system', 'light', 'dark')),
  shopping_priority text not null default 'balanced'
    check (shopping_priority in ('balanced', 'battery', 'performance', 'portability')),
  face_id_enabled boolean not null default false,
  notify_price_drops boolean not null default true,
  notify_tracking boolean not null default true,
  notify_insights boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tracked_products (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  -- Lowest price when tracking started; drops and savings are measured against it.
  previous_price numeric(12, 2) not null check (previous_price > 0),
  alerts_enabled boolean not null default true,
  drop_threshold_percent numeric(5, 2) not null default 5 check (drop_threshold_percent > 0 and drop_threshold_percent <= 90),
  tracked_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.saved_products (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.recently_viewed (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  query text not null check (length(trim(query)) > 0),
  query_key text generated always as (lower(trim(query))) stored,
  searched_at timestamptz not null default now(),
  unique (user_id, query_key)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('price_drop', 'better_price', 'tracking_started', 'tip')),
  product_id uuid references public.products (id) on delete set null,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index search_history_user_idx on public.search_history (user_id, searched_at desc);
create index recently_viewed_user_idx on public.recently_viewed (user_id, viewed_at desc);

alter table public.profiles enable row level security;
alter table public.tracked_products enable row level security;
alter table public.saved_products enable row level security;
alter table public.recently_viewed enable row level security;
alter table public.search_history enable row level security;
alter table public.notifications enable row level security;

create policy "Users read their own profile" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "Users update their own profile" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Users manage their tracked products" on public.tracked_products
  for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users manage their saved products" on public.saved_products
  for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users manage their recently viewed" on public.recently_viewed
  for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users manage their search history" on public.search_history
  for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Notifications are created by the backend only; users can read, mark read and delete theirs.
create policy "Users read their notifications" on public.notifications
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users mark their notifications read" on public.notifications
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users delete their notifications" on public.notifications
  for delete to authenticated using ((select auth.uid()) = user_id);

-- The app listens for new alerts over Supabase Realtime and shows them as local notifications.
alter publication supabase_realtime add table public.notifications;
