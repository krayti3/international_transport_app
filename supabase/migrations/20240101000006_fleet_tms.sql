-- Migration: fleet & TMS extensions, reconciled with the existing schema.
-- NOTE: the app's "trips" table is named `advances`, and `clients`/`trucks`/
-- `trip_orders` already exist (with `plate`, `name`, `price` columns used by the
-- UI). We ADD the new structure instead of recreating tables, so nothing breaks.
-- Safe to re-run (guards on if not exists / add column if not exists).

-- 1. Trailers (new table).
create table if not exists public.trailers (
  id bigserial primary key,
  plate_number text not null,
  type text -- ثلاجة، عادية، إلخ
);

-- 2. Unified vehicle documents (covers trucks AND trailers). Distinct from the
--    older `truck_documents` table so the new fleet-alerts feature is isolated.
create table if not exists public.documents (
  id bigserial primary key,
  vehicle_type text not null check (vehicle_type in ('truck', 'trailer')),
  vehicle_id bigint not null,
  document_name text not null,
  expiry_date date not null,
  alert_days_before integer not null default 15
);

create index if not exists documents_vehicle_idx
  on public.documents (vehicle_type, vehicle_id);

-- 3. Extend trucks with odometer / oil-change tracking.
alter table public.trucks add column if not exists brand text;
alter table public.trucks add column if not exists current_km numeric not null default 0;
alter table public.trucks add column if not exists oil_change_km numeric;

-- 4. Link a mission (advances row) to its truck + trailer.
alter table public.advances
  add column if not exists truck_id bigint references public.trucks (id) on delete set null;
alter table public.advances
  add column if not exists trailer_id bigint references public.trailers (id) on delete set null;

-- 5. Trip legs (outbound / return) per client, under a mission.
alter table public.trip_orders
  add column if not exists trip_id bigint references public.advances (id) on delete cascade;
alter table public.trip_orders
  add column if not exists direction text check (direction in ('outbound', 'return'));
alter table public.trip_orders
  add column if not exists specific_expenses numeric not null default 0;

-- 6. Make the new tables manageable by the team (same permissive pattern as the
--    rest of the business tables) and expose them to the API.
do $$
declare
  t text;
begin
  foreach t in array array['trailers', 'documents']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "Manage %I" on public.%I', t, t);
    execute format('create policy "Manage %I" on public.%I for all using (true) with check (true)', t, t);
    execute format('grant select, insert, update, delete on table public.%I to authenticated, anon', t);
  end loop;
end $$;
