-- Products table for trip routes/offerings
-- These represent the international transport routes/products
create table if not exists public.products (
  id bigserial primary key,
  name text not null,
  price numeric not null default 0,
  is_international boolean not null default true,
  created_at timestamptz default now()
);

-- Trip order items table for line items in trip orders
create table if not exists public.trip_order_items (
  id bigserial primary key,
  trip_order_id bigint not null references public.trip_orders(id) on delete cascade,
  product_id bigint not null references public.products(id) on delete cascade,
  quantity integer not null default 1,
  unit_price numeric not null default 0,
  created_at timestamptz default now()
);

-- Indexes
create index if not exists idx_products_international on public.products(is_international);
create index if not exists idx_trip_order_items_order on public.trip_order_items(trip_order_id);

-- RLS
alter table public.products enable row level security;
alter table public.trip_order_items enable row level security;

-- Policies for products
create policy "Authenticated users can view products"
  on public.products for select
  to authenticated
  using (true);

create policy "Authenticated users can insert products"
  on public.products for insert
  to authenticated
  with check (true);

-- Policies for trip_order_items
create policy "Authenticated users can view trip order items"
  on public.trip_order_items for select
  to authenticated
  using (true);

create policy "Authenticated users can insert trip order items"
  on public.trip_order_items for insert
  to authenticated
  with check (true);
