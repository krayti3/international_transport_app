-- =====================================================================
-- International Transport App â€” Consolidated Supabase Migration
-- =====================================================================
-- HOW TO RUN:
--   1. Open your Supabase project â†’ SQL Editor â†’ New query.
--   2. Paste the ENTIRE contents of this file.
--   3. Click "Run".
--
-- This file concatenates every migration in supabase/migrations/ in the
-- correct dependency order. All statements are idempotent (guarded with
-- IF NOT EXISTS / DROP ... IF EXISTS / ON CONFLICT), so it is safe to
-- re-run.
--
-- NOTE: A few base tables (clients, trucks, trip_orders, invoices) are
-- assumed to already exist in the project's base schema; the ALTER TABLE
-- statements below reconcile/extend them. If any of them is missing you
-- will get a "relation does not exist" error â€” create the base schema
-- first, then re-run this file.
-- =====================================================================


-- =====================================================================
-- 01. 20240101000000_fix_schema.sql
-- =====================================================================

-- Migration: fix schema for RBAC users table and clients.address column
-- Safe to re-run: all objects are guarded with if not exists / drop if exists.

-- 1. Create the users table used for role-based access control (RBAC).
--    The app inserts {id, email, role} where id is the auth user id (uuid)
--    and reads role back via SELECT role FROM users WHERE id = auth.uid().
create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  role text not null default 'secretary' check (role in ('admin','secretary','driver')),
  created_at timestamptz not null default now()
);

-- 2. Ensure all columns the app reads/writes on clients exist.
--    The app uses: name, phone, address, city, created_at.
--    Add any that are missing (safe to re-run thanks to if not exists).
alter table public.clients
  add column if not exists name text;

alter table public.clients
  add column if not exists phone text;

alter table public.clients
  add column if not exists address text not null default '';

alter table public.clients
  add column if not exists city text not null default '';

alter table public.clients
  add column if not exists nom_contact text;

alter table public.clients
  add column if not exists adresse_facturation text;

alter table public.clients
  add column if not exists created_at timestamptz not null default now();

-- 3. Enable Row Level Security on users and create self-scoped policies so a
--    user can only read/insert/update/delete their own row.
alter table public.users enable row level security;

drop policy if exists "Users can read own row" on public.users;
create policy "Users can read own row"
  on public.users for select
  using (auth.uid() = id);

drop policy if exists "Users can insert own row" on public.users;
create policy "Users can insert own row"
  on public.users for insert
  with check (auth.uid() = id);

drop policy if exists "Users can update own row" on public.users;
create policy "Users can update own row"
  on public.users for update
  using (auth.uid() = id);

drop policy if exists "Users can delete own row" on public.users;
create policy "Users can delete own row"
  on public.users for delete
  using (auth.uid() = id);

-- 4. Grant API access to the users table for the Supabase API roles.
grant select, insert, update, delete on table public.users to authenticated, anon;

-- 5. Allow the app to read/write the clients table.
--    RLS is already enabled on clients in the base schema, but no policy
--    permitted writes, so inserts failed with "violates row-level security
--    policy" (SQLSTATE 42501). Clients are shared business data for the team,
--    so add a single permissive ALL policy. Safe to re-run (drop if exists).
alter table public.clients enable row level security;

drop policy if exists "Clients are manageable by authenticated" on public.clients;
create policy "Clients are manageable by authenticated"
  on public.clients
  for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.clients to authenticated, anon;

-- 6. User management UI support.
--    The base RLS only lets a user read/update their OWN row, which blocks the
--    admin "manage roles" screen (needs to list all users and edit others).
--    Add a SECURITY DEFINER helper to detect admins without recursing through
--    RLS, then allow the team to read all users and admins to change roles.
create or replace function public.is_admin(check_uid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users where id = check_uid and role = 'admin'
  );
$$;

drop policy if exists "Users are viewable by team" on public.users;
create policy "Users are viewable by team"
  on public.users for select
  using (true);

drop policy if exists "Admins can change roles" on public.users;
create policy "Admins can change roles"
  on public.users for update
  using (public.is_admin(auth.uid()))
  with check (true);

-- 7. Allow the app to read/write all business tables.
--    Like the clients table, these tables have RLS enabled in the base schema
--    but no policy permitted writes, so inserts/updates failed with
--    "violates row-level security policy" (42501). Add permissive ALL policies
--    (internal business app). Safe to re-run; skips tables that don't exist.
do $$
declare
  t text;
begin
  foreach t in array array[
    'trucks',
    'drivers',
    'trip_orders',
    'invoices',
    'payments',
    'payment_invoice_allocations',
    'treasury_transactions',
    'truck_documents',
    'driver_salaries',
    'app_settings'
  ]
  loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "Manage %I" on public.%I', t, t);
    execute format('create policy "Manage %I" on public.%I for all using (true) with check (true)', t, t);
    execute format('grant select, insert, update, delete on table public.%I to authenticated, anon', t);
  end loop;
end $$;

-- 8. Reconcile trip_orders columns the app expects. The live DB lagged behind
--    the app (e.g. missing 'departure_date' caused PGRST204 on insert). Add any
--    that are missing; safe to re-run thanks to if not exists.
alter table public.trip_orders
  add column if not exists client_id integer,
  add column if not exists route text,
  add column if not exists price numeric,
  add column if not exists departure_date text,
  add column if not exists status text,
  add column if not exists driver_id integer;

-- 9. Reconcile drivers columns the app expects. The live DB lagged behind the
--    app, so 'base_salary' / 'bonus_percentage' (and possibly 'license',
--    'status') were silently dropped on insert. Add any missing columns; safe
--    to re-run thanks to if not exists.
alter table public.drivers
  add column if not exists license text,
  add column if not exists base_salary numeric,
  add column if not exists bonus_percentage numeric,
  add column if not exists status text;

-- 10. Assign a trip to a driver and store a default truck per driver.
alter table public.drivers
  add column if not exists default_truck_id integer;

alter table public.trip_orders
  add column if not exists truck_id integer;


-- =====================================================================
-- 02. 20240101000001_advances.sql
-- =====================================================================

-- Migration: create the advances (Ø§Ù„Ø¹ÙÙ‡Ø¯) table for driver trip advances.
-- Safe to re-run: all objects are guarded with if not exists / drop if exists.

-- 1. Create the advances table. A row represents cash an advance the secretary
--    hands a driver before a trip (amount_given on date_out). After the trip the
--    driver reports actual spending (amount_spent) and returns the remainder
--    (amount_returned) on date_return; status flips from 'pending' to 'settled'.
--    receipts_images holds links/urls to the receipt photos (text array).
create table if not exists public.advances (
  id integer generated always as identity primary key,
  driver_id integer references public.drivers (id) on delete cascade,
  amount_given numeric not null default 0,
  date_out text not null default to_char(now(), 'YYYY-MM-DD'),
  status text not null default 'pending' check (status in ('pending', 'settled')),
  amount_spent numeric,
  amount_returned numeric,
  receipts_images text[] not null default '{}',
  date_return text,
  created_at timestamptz not null default now()
);

create index if not exists advances_driver_id_idx on public.advances (driver_id);
create index if not exists advances_status_idx on public.advances (status);

-- 2. Enable RLS and add a permissive ALL policy (internal business app), plus
--    grant API access. Safe to re-run.
alter table public.advances enable row level security;

drop policy if exists "Manage advances" on public.advances;
create policy "Manage advances"
  on public.advances for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.advances to authenticated, anon;


-- =====================================================================
-- 03. 20240101000002_storage.sql
-- =====================================================================

-- Migration: create the public 'receipts' storage bucket and policies so
-- drivers/secretary can upload and read receipt photos attached to advances.
-- Safe to re-run: bucket insert uses on conflict do nothing; policies drop first.

insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

drop policy if exists "Receipts are public readable" on storage.objects;
create policy "Receipts are public readable"
  on storage.objects for select
  using (bucket_id = 'receipts');

drop policy if exists "Receipts are manageable by authenticated" on storage.objects;
create policy "Receipts are manageable by authenticated"
  on storage.objects for all
  using (bucket_id = 'receipts')
  with check (bucket_id = 'receipts');


-- =====================================================================
-- 04. 20240101000003_trip_confirm.sql
-- =====================================================================

-- Migration: support the secretary "confirm trip" workflow.
-- The secretary starts a trip (advance) with status 'en_route' and may attach
-- free-form notes. Safe to re-run.

-- 1. Add a notes column to the advances (trips) table.
alter table public.advances
  add column if not exists notes text not null default '';

-- 2. Allow the 'en_route' status alongside 'pending'/'settled'. The inline
--    CHECK created by the base migration is named advances_status_check; drop
--    it (if present) and recreate with the new allowed values.
alter table public.advances drop constraint if exists advances_status_check;
alter table public.advances
  add constraint advances_status_check
  check (status in ('pending', 'en_route', 'settled'));

-- 3. Make 'en_route' the default status for new trips.
alter table public.advances alter column status set default 'en_route';


-- =====================================================================
-- 05. 20240101000004_rbac_softdelete.sql
-- =====================================================================

-- Migration: role-based profile data + soft delete for advances.
-- The app already has a 'users' RBAC table (id uuid, email, role, created_at)
-- managed by an earlier migration, so we extend it with a profile 'name'
-- instead of creating a duplicate 'profiles' table that would break the
-- existing role system. Safe to re-run.

-- 1. Profile name on the users table.
alter table public.users add column if not exists name text not null default '';

-- 2. Soft delete flag on advances (trips). Rows are never hard-deleted by the
--    app; "delete" flips is_deleted to true and they disappear from the
--    secretary's view while staying in the archive.
alter table public.advances
  add column if not exists is_deleted boolean not null default false;

create index if not exists advances_is_deleted_idx on public.advances (is_deleted);


-- =====================================================================
-- 06. 20240101000005_notifications.sql
-- =====================================================================

-- Migration: realtime notifications table.
-- The app subscribes to this table; when the secretary creates/closes a trip
-- the app inserts a row targeted at the relevant user(s) and it pops up
-- instantly on their device (desktop or phone). Safe to re-run.

create table if not exists public.notifications (
  id bigserial primary key,
  user_id uuid references auth.users (id) on delete cascade,
  title text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_idx on public.notifications (user_id);

-- RLS: a user sees only notifications aimed at them or broadcast (user_id null).
alter table public.notifications enable row level security;

drop policy if exists "Notifications readable by target or broadcast" on public.notifications;
create policy "Notifications readable by target or broadcast"
  on public.notifications for select
  using (user_id is null or user_id = auth.uid());

drop policy if exists "Authenticated can create notifications" on public.notifications;
create policy "Authenticated can create notifications"
  on public.notifications for insert
  with check (auth.uid() is not null);

drop policy if exists "Recipient or admin can delete notifications" on public.notifications;
create policy "Recipient or admin can delete notifications"
  on public.notifications for delete
  using (user_id = auth.uid() or public.is_admin(auth.uid()));

grant select, insert, delete on table public.notifications to authenticated, anon;

-- Stream changes over Realtime.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;


-- =====================================================================
-- 07. 20240101000006_fleet_tms.sql
-- =====================================================================

-- Migration: fleet & TMS extensions, reconciled with the existing schema.
-- NOTE: the app's "trips" table is named `advances`, and `clients`/`trucks`/
-- `trip_orders` already exist (with `plate`, `name`, `price` columns used by the
-- UI). We ADD the new structure instead of recreating tables, so nothing breaks.
-- Safe to re-run (guards on if not exists / add column if not exists).

-- 1. Trailers (new table).
create table if not exists public.trailers (
  id bigserial primary key,
  plate_number text not null,
  type text -- Ø«Ù„Ø§Ø¬Ø©ØŒ Ø¹Ø§Ø¯ÙŠØ©ØŒ Ø¥Ù„Ø®
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


-- =====================================================================
-- 08. 20240101000007_treasury_tva.sql
-- =====================================================================

-- Migration: create the treasury (cash flow) and TVA app-settings tables.
-- Safe to re-run: all objects are guarded with if not exists / do blocks.
--
-- Column names intentionally match the existing app models/service:
--   * TreasuryTransaction model + SupabaseService use the `type` column
--     (values: capital_injection, trip_revenue, owner_withdrawal,
--      office_expense, salary, trip_expense).
--   * AppSettings model + updateAppSettings use `is_enabled` and
--     `percentage` (the TVA rate).
--
-- If you previously ran the original SQL (columns transaction_type /
-- tva_percentage / is_tva_enabled), the rename blocks below migrate that
-- existing schema to the names the app actually expects.

-- 1. Central treasury transactions table. The current balance is NEVER stored;
--    it is computed on read as SUM(deposits) - SUM(withdrawals/expenses).
create table if not exists public.treasury_transactions (
  id bigint generated always as identity primary key,
  type text not null
    check (type in (
      'capital_injection',  -- ØªØ²ÙˆÙŠØ¯ ØµØ§Ø­Ø¨ Ø§Ù„Ù…Ø´Ø±ÙˆØ¹
      'trip_revenue',       -- Ø¯Ø®Ù„ ÙÙˆØ§ØªÙŠØ± Ø§Ù„Ø±Ø­Ù„Ø§Øª
      'owner_withdrawal',   -- Ø³Ø­Ø¨ ØµØ§Ø­Ø¨ Ø§Ù„Ù…Ø´Ø±ÙˆØ¹
      'office_expense',     -- Ù…ØµØ§Ø±ÙŠÙ Ø§Ù„Ù…ÙƒØªØ¨
      'salary',             -- Ø£Ø¬ÙˆØ± Ø§Ù„Ù…ÙˆØ¸ÙÙŠÙ† ÙˆØ§Ù„Ø³Ø§Ø¦Ù‚ÙŠÙ†
      'trip_expense'        -- Ù…ØµØ§Ø±ÙŠÙ Ø§Ù„Ø±Ø­Ù„Ø§Øª ÙˆØ§Ù„Ø¹ÙÙ‡Ø¯
    )),
  amount numeric not null check (amount >= 0),
  description text,
  created_at timestamptz not null default now()
);

-- Migrate an old-schema table that used transaction_type instead of type.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'treasury_transactions'
      and column_name = 'transaction_type'
  ) then
    alter table public.treasury_transactions rename column transaction_type to type;
  end if;
end $$;

create index if not exists treasury_transactions_type_idx
  on public.treasury_transactions (type);
create index if not exists treasury_transactions_created_at_idx
  on public.treasury_transactions (created_at);

-- 2. Single-row application settings (TVA control). The CHECK constraint on
--    id forces the table to hold exactly one row.
create table if not exists public.app_settings (
  id integer primary key default 1,
  percentage numeric not null default 20,       -- Ù†Ø³Ø¨Ø© Ø§Ù„Ù€ TVA Ø§Ù„Ø§ÙØªØ±Ø§Ø¶ÙŠØ© (Ù…Ø«Ù„Ø§Ù‹ 20%)
  is_enabled boolean not null default true,     -- ØªÙØ¹ÙŠÙ„ Ø£Ùˆ Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ù€ TVA ØªÙ…Ø§Ù…Ø§Ù‹
  constraint app_settings_single_row check (id = 1)
);

-- Migrate an old-schema table that used tva_percentage / is_tva_enabled.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_settings'
      and column_name = 'tva_percentage'
  ) then
    alter table public.app_settings rename column tva_percentage to percentage;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_settings'
      and column_name = 'is_tva_enabled'
  ) then
    alter table public.app_settings rename column is_tva_enabled to is_enabled;
  end if;
end $$;

-- Seed the single settings row on first run.
insert into public.app_settings (id, percentage, is_enabled)
values (1, 20, true)
on conflict (id) do nothing;

-- 3. Enable RLS and add permissive ALL policies (internal business app), plus
--    grant API access. Safe to re-run.
alter table public.treasury_transactions enable row level security;
alter table public.app_settings enable row level security;

drop policy if exists "Manage treasury_transactions" on public.treasury_transactions;
create policy "Manage treasury_transactions"
  on public.treasury_transactions for all
  using (true)
  with check (true);

drop policy if exists "Manage app_settings" on public.app_settings;
create policy "Manage app_settings"
  on public.app_settings for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.treasury_transactions to authenticated, anon;
grant select, insert, update, delete on table public.app_settings to authenticated, anon;


-- =====================================================================
-- 09. 20240101000008_treasury_receipts.sql
-- =====================================================================

-- Migration: attach a receipt image to each treasury transaction.
-- Lets the secretary photo the office-rent / salary voucher from the phone and
-- upload it to Supabase Storage; the admin can audit any expense from anywhere.
-- Safe to re-run.

alter table public.treasury_transactions
  add column if not exists receipt_url text;

create index if not exists treasury_transactions_receipt_idx
  on public.treasury_transactions (receipt_url);


-- =====================================================================
-- 10. 20240101000009_advance_treasury_link.sql
-- =====================================================================

-- Migration: link each advance (Ø¹Ù‡Ø¯Ø©) to its treasury (cash-box) postings.
-- Stores the id of the base outflow tx and the optional overspend tx so the
-- app can keep treasury_transactions in sync with advances. Safe to re-run.

alter table public.advances
  add column if not exists treasury_tx_id bigint,
  add column if not exists treasury_tx_extra_id bigint;

create index if not exists advances_treasury_tx_idx
  on public.advances (treasury_tx_id);


-- =====================================================================
-- 11. 20240101000011_truck_maintenance.sql
-- =====================================================================

-- Migration: per-truck maintenance & depreciation expenses.
-- Records operational expenses that are deducted directly from net profit.
create table if not exists public.truck_maintenance (
  id bigserial primary key,
  truck_id bigint not null references public.trucks (id) on delete cascade,
  expense_type text not null, -- oil_change | tires | insurance | technical_inspection | depreciation | other
  description text,
  amount numeric not null default 0,
  km_at_time numeric, -- odometer reading at time of expense
  due_date date, -- for insurance, inspection etc. (next due date)
  created_at timestamp not null default now()
);

create index if not exists truck_maintenance_truck_idx
  on public.truck_maintenance (truck_id);

alter table public.truck_maintenance enable row level security;
drop policy if exists "Manage truck_maintenance" on public.truck_maintenance;
create policy "Manage truck_maintenance" on public.truck_maintenance for all using (true) with check (true);
grant select, insert, update, delete on table public.truck_maintenance to authenticated, anon;


-- =====================================================================
-- 11b. 20250716000001_add_truck_maintenance_payment_fields.sql
-- =====================================================================

-- Migration: add payment tracking fields to truck_maintenance.
-- Extends the existing table with provider_name, payment_status, and
-- maintenance_date so that repair costs can be tracked independently
-- from the secretary's cash-box (treasury).
-- Safe to re-run: all ALTERs are guarded with IF NOT EXISTS.

alter table public.truck_maintenance
  add column if not exists provider_name text,
  add column if not exists payment_status text not null default 'paid_by_owner',
  add column if not exists maintenance_date timestamp not null default now();

create index if not exists truck_maintenance_payment_status_idx
  on public.truck_maintenance (payment_status);

create index if not exists truck_maintenance_maintenance_date_idx
  on public.truck_maintenance (maintenance_date);


-- =====================================================================
-- 12. 20240101000012_driver_user_link.sql
-- =====================================================================

-- Link drivers to auth users so the driver app can auto-detect
-- which driver record belongs to the logged-in user.
alter table public.drivers
  add column if not exists user_id uuid references auth.users(id) on delete set null;

create index if not exists drivers_user_id_idx
  on public.drivers (user_id);


-- =====================================================================
-- 13. 0004_payments_allocations.sql
-- =====================================================================

-- Ø¬Ø¯Ø§ÙˆÙ„ Ø§Ù„Ø¯ÙØ¹Ø§Øª ÙˆØªÙˆØ²ÙŠØ¹Ù‡Ø§ Ø¹Ù„Ù‰ Ø§Ù„ÙÙˆØ§ØªÙŠØ± (Ù…ØªÙˆØ§ÙÙ‚Ø© Ù…Ø¹ Ø£Ø³Ù…Ø§Ø¡ Ø£Ø¹Ù…Ø¯Ø© Ø§Ù„ÙƒÙˆØ¯ ÙÙŠ Dart)
-- Ù…Ø·Ø§Ø¨Ù‚Ø© Ù„Ù€ models/payment.dart Ùˆ models/payment_invoice_allocation.dart
-- Ø§Ù„Ø¹Ù„Ø§Ù‚Ø© Ø¨ÙŠÙ† Ø§Ù„Ø¯ÙØ¹Ø© ÙˆØ§Ù„ÙÙˆØ§ØªÙŠØ± Ù‡ÙŠ Many-to-Many Ø¹Ø¨Ø± Ø§Ù„Ø¬Ø¯ÙˆÙ„ Ø§Ù„ÙˆØ³ÙŠØ·.
-- Ù…Ù„Ø§Ø­Ø¸Ø©: ÙŠØ¹ØªÙ…Ø¯ Ù‡Ø°Ø§ Ø§Ù„Ø¬Ø²Ø¡ Ø¹Ù„Ù‰ ÙˆØ¬ÙˆØ¯ Ø§Ù„Ø¬Ø¯ÙˆÙ„ÙŠÙ† clients Ùˆ invoices Ù…Ø³Ø¨Ù‚Ø§Ù‹.

-- 1) Ø¬Ø¯ÙˆÙ„ Ø§Ù„Ø¯ÙØ¹Ø§Øª Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠØ© (payments)
CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    client_id BIGINT REFERENCES clients(id),
    amount NUMERIC NOT NULL,                       -- Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø°ÙŠ Ø¯ÙØ¹Ù‡ Ø§Ù„Ø²Ø¨ÙˆÙ† (Ù…Ø«Ù„Ø§Ù‹ 50000)
    method TEXT,                                   -- Ø·Ø±ÙŠÙ‚Ø© Ø§Ù„Ø¯ÙØ¹ (ØªØ­ÙˆÙŠÙ„ Ø¨Ù†ÙƒÙŠØŒ Ø´ÙŠÙƒØŒ Ù†Ù‚Ø¯Ø§Ù‹ØŒ ÙƒÙ…Ø¨ÙŠØ§Ù„Ø©)
    ref TEXT,                                      -- Ø±Ù‚Ù… Ø§Ù„Ø´ÙŠÙƒ Ø£Ùˆ Ø§Ù„Ù…Ø±Ø¬Ø¹/Ø§Ù„ÙˆØµÙ„
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2) Ø§Ù„Ø¬Ø¯ÙˆÙ„ Ø§Ù„ÙˆØ³ÙŠØ· Ù„ØªÙ‚Ø³ÙŠÙ… Ø§Ù„Ø¯ÙØ¹Ø© Ø¹Ù„Ù‰ Ø§Ù„ÙÙˆØ§ØªÙŠØ± (payment_invoice_allocations)
CREATE TABLE IF NOT EXISTS payment_invoice_allocations (
    id BIGSERIAL PRIMARY KEY,
    payment_id BIGINT REFERENCES payments(id) ON DELETE CASCADE,
    invoice_id BIGINT REFERENCES invoices(id) ON DELETE CASCADE,
    allocated_amount NUMERIC NOT NULL              -- ÙƒÙ… Ø®ÙØµØµ Ù…Ù† Ù‡Ø°Ù‡ Ø§Ù„Ø¯ÙØ¹Ø© Ù„Ù‡Ø°Ù‡ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø¨Ø§Ù„ØªØ­Ø¯ÙŠØ¯
);

CREATE INDEX IF NOT EXISTS idx_payments_client_id ON payments(client_id);
CREATE INDEX IF NOT EXISTS idx_allocations_payment_id ON payment_invoice_allocations(payment_id);
CREATE INDEX IF NOT EXISTS idx_allocations_invoice_id ON payment_invoice_allocations(invoice_id);

-- =====================================================================
-- 14. 20240101000013_trip_order_documents.sql
-- =====================================================================

-- Migration: create trip_order_documents table and trip-documents storage bucket
-- for customs documents (permits, CMR, T1/T2, etc.) attached to trip_orders.
-- Safe to re-run: all objects are guarded with if not exists / drop if exists.

-- 1. Create the trip_order_documents table.
create table if not exists public.trip_order_documents (
  id bigserial primary key,
  trip_order_id bigint not null references public.trip_orders (id) on delete cascade,
  file_name text not null,
  file_url text not null,
  file_type text not null default 'image',
  document_type text not null default 'customs',
  created_at timestamptz not null default now()
);

create index if not exists trip_order_documents_trip_order_id_idx
  on public.trip_order_documents (trip_order_id);

-- 2. Create the public 'trip-documents' storage bucket and policies.
insert into storage.buckets (id, name, public)
values ('trip-documents', 'trip-documents', true)
on conflict (id) do nothing;

drop policy if exists "Trip documents are public readable" on storage.objects;
create policy "Trip documents are public readable"
  on storage.objects for select
  using (bucket_id = 'trip-documents');

drop policy if exists "Trip documents are manageable by authenticated" on storage.objects;
create policy "Trip documents are manageable by authenticated"
  on storage.objects for all
  using (bucket_id = 'trip-documents')
  with check (bucket_id = 'trip-documents');

-- 3. Enable RLS and add permissive ALL policy on the table.
alter table public.trip_order_documents enable row level security;

drop policy if exists "Manage trip_order_documents" on public.trip_order_documents;
create policy "Manage trip_order_documents"
  on public.trip_order_documents for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.trip_order_documents to authenticated, anon;


-- =====================================================================
-- 15. 20250720210000_clients_invoice_with_tva.sql
-- =====================================================================

-- Migration: add invoice_with_tva column to clients table.
-- Safe to re-run: guarded with IF NOT EXISTS.

alter table public.clients
  add column if not exists invoice_with_tva boolean not null default false;

-- Bump cache.
update public.system_settings set updated_at = now() where id = 1;


-- =====================================================================
-- 16. 20250719110000_fleet_doc_type_free_text.sql
-- =====================================================================

-- Migration: convert fleet_documents.category_id (FK) into free-text doc_type
DO $$
DECLARE
  v_conname text;
BEGIN
  SELECT tc.constraint_name
    INTO v_conname
    FROM information_schema.table_constraints tc
   WHERE tc.table_schema = 'public'
     AND tc.table_name   = 'fleet_documents'
     AND tc.constraint_type = 'FOREIGN KEY'
     AND tc.constraint_name = 'fleet_documents_category_id_fkey';

  IF v_conname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.fleet_documents DROP CONSTRAINT %I;', v_conname);
  END IF;
END $$;

DO $$
DECLARE
  v_has_old int;
BEGIN
  SELECT COUNT(*)
    INTO v_has_old
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name   = 'fleet_documents'
     AND column_name  = 'category_id';

  IF v_has_old = 1 THEN
    EXECUTE 'ALTER TABLE public.fleet_documents RENAME COLUMN category_id TO doc_type;';
  END IF;
END $$;

DO $$
DECLARE
  v_dtype text;
BEGIN
  SELECT data_type
    INTO v_dtype
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name   = 'fleet_documents'
     AND column_name  = 'doc_type';

  IF v_dtype IS NOT NULL AND v_dtype <> 'text' THEN
    EXECUTE 'ALTER TABLE public.fleet_documents ALTER COLUMN doc_type TYPE text USING doc_type::text;';
  END IF;
END $$;

ALTER TABLE public.fleet_documents ALTER COLUMN doc_type DROP NOT NULL;

UPDATE public.system_settings SET updated_at = now() WHERE id = 1;


-- =====================================================================
-- 17. 20250722000000_trailer_maintenance.sql
-- =====================================================================

-- trailer_maintenance table
create table if not exists public.trailer_maintenance (
  id            serial primary key,
  trailer_id    integer not null,
  expense_type  text not null,
  description   text,
  amount        numeric not null,
  km_at_time    numeric,
  due_date      text,
  payment_status text default 'paid_by_owner',
  provider_name text,
  maintenance_date text not null,
  created_at    text default now(),
  updated_at    text default now()
);

create index if not exists idx_trailer_maintenance_trailer_id
  on public.trailer_maintenance (trailer_id);

alter table public.trailer_maintenance enable row level security;

drop policy if exists "Allow authenticated access" on public.trailer_maintenance;
create policy "Allow authenticated access"
  on public.trailer_maintenance
  for all
  to authenticated
  using (true)
  with check (true);

update public.system_settings set updated_at = now() where id = 1;


-- =====================================================================
-- 18. 20250723000000_add_model_and_oil_tracking.sql
-- =====================================================================

-- Migration: add truck model column, daily km average, and oil-change tracking fields
-- Safe to re-run: all ALTERs are guarded with IF NOT EXISTS.

-- 1. Trucks: add model text and daily_km_average numeric
alter table public.trucks
  add column if not exists model text,
  add column if not exists daily_km_average numeric;

-- 2. Truck maintenance: add oil change tracking columns
alter table public.truck_maintenance
  add column if not exists oil_interval_km numeric,
  add column if not exists next_change_km numeric,
  add column if not exists next_change_date date;

-- Bump cache
update public.system_settings set updated_at = now() where id = 1;


-- =====================================================================
-- 19. 20250724000000_add_default_driver_to_trucks.sql
-- =====================================================================

-- Migration: add default_driver_id column to trucks
-- Safe to re-run: guarded with IF NOT EXISTS.

alter table public.trucks
  add column if not exists default_driver_id integer references public.drivers(id) on delete set null;

-- Unique constraint: one truck per default driver at most
create unique index if not exists idx_trucks_default_driver_id
  on public.trucks (default_driver_id)
  where default_driver_id is not null;


-- =====================================================================
-- 20. 20250101000015_truck_locations.sql
-- =====================================================================

-- Add GPS location tracking columns to the trucks table
-- These columns are used by the truck tracking screen for realtime fleet monitoring
alter table public.trucks
  add column if not exists current_latitude double precision,
  add column if not exists current_longitude double precision,
  add column if not exists current_location text;

-- Enable RLS on the trucks table if not already enabled
alter table public.trucks enable row level security;

drop policy if exists "Authenticated users can view truck locations" on public.trucks;
create policy "Authenticated users can view truck locations"
  on public.trucks for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users can update truck locations" on public.trucks;
create policy "Authenticated users can update truck locations"
  on public.trucks for update
  to authenticated
  using (true)
  with check (true);


-- =====================================================================
-- 21. 20250719100000_trucks_default_trailer.sql
-- =====================================================================

-- Migration: Adds the "default trailer" concept to the transport app.
-- Each truck head (public.trucks) can reference a default trailer
-- (public.trailers) via the new default_trailer_id column.
-- The column is nullable: a truck may have no default trailer.
-- The foreign key uses ON DELETE SET NULL so removing a trailer
-- does not break the referencing truck.
-- All statements are guarded to be safe to re-run.

-- 1. Add the nullable default_trailer_id column to public.trucks.
alter table public.trucks
  add column if not exists default_trailer_id integer;

-- 2. Add the foreign key constraint to public.trailers(id).
--    Postgres has no "ADD CONSTRAINT IF NOT EXISTS", so guard it in PL/pgSQL.
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'trucks_default_trailer_fkey'
      and table_schema = 'public'
      and table_name = 'trucks'
  ) then
    alter table public.trucks
      add constraint trucks_default_trailer_fkey
      foreign key (default_trailer_id)
      references public.trailers(id)
      on delete set null;
  end if;
end $$;

-- 3. Bump the cache (project convention).
update public.system_settings set updated_at = now() where id = 1;


-- =====================================================================
-- 22. 20250720100000_trucks_status_column.sql
-- =====================================================================

-- Add status column to trucks table if missing.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'trucks'
      and column_name = 'status'
  ) then
    alter table public.trucks
      add column status text not null default 'active';
  end if;
end $$;

-- Bump cache.
update public.system_settings set updated_at = now() where id = 1;


-- =====================================================================
-- 23. 20250720100001_trailers_status_column.sql
-- =====================================================================

-- Add status column to trailers table if missing.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'trailers'
      and column_name = 'status'
  ) then
    alter table public.trailers
      add column status text not null default 'active';
  end if;
end $$;

-- Bump cache.
update public.system_settings set updated_at = now() where id = 1;


-- =====================================================================
-- 24. 20250725000000_add_truck_purchase_weight_power.sql
-- =====================================================================

-- Migration: add purchase date, empty weight, and fiscal power to trucks
-- Safe to re-run: all ALTERs are guarded with IF NOT EXISTS.

alter table public.trucks
  add column if not exists purchase_date date,
  add column if not exists empty_weight numeric,
  add column if not exists fiscal_power numeric;

-- Bump cache
update public.system_settings set updated_at = now() where id = 1;



-- =====================================================================
-- 20260724000001: Repair invoices and workshop payments tables
-- =====================================================================
-- جداول فواتير إصلاح الورش والدفعات الخاصة بها
-- يُطبَّق مبدأ FIFO (أقدم فاتورة أولاً) لتسوية الديون

-- 1) جدول فواتير الإصلاح (repair_invoices)
create table if not exists public.repair_invoices (
  id bigserial primary key,
  workshop_id text not null,
  vehicle_id text,
  vehicle_type text check (vehicle_type in ('truck', 'trailer')),
  invoice_number text not null,
  total_amount numeric not null default 0,
  paid_amount numeric not null default 0,
  remaining_amount numeric generated always as (total_amount - paid_amount) stored,
  status text not null default 'unpaid' check (status in ('unpaid', 'partially_paid', 'paid')),
  date timestamp not null default now(),
  description text,
  payment_method text,
  payment_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_repair_invoices_workshop on public.repair_invoices(workshop_id);
create index if not exists idx_repair_invoices_vehicle on public.repair_invoices(vehicle_id);
create index if not exists idx_repair_invoices_status on public.repair_invoices(status);
create index if not exists idx_repair_invoices_date on public.repair_invoices(date);
create unique index if not exists idx_repair_invoices_number on public.repair_invoices(invoice_number);

-- 2) جدول دفعات تسوية فواتير الورش (workshop_payments)
create table if not exists public.workshop_payments (
  id bigserial primary key,
  workshop_id text not null,
  amount numeric not null,
  method text not null,
  ref text,
  vehicle_type text check (vehicle_type in ('truck', 'trailer')),
  vehicle_id text,
  payment_date timestamp not null default now(),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_workshop_payments_workshop on public.workshop_payments(workshop_id);
create index if not exists idx_workshop_payments_date on public.workshop_payments(payment_date);

-- 3) جدول توزيع الدفعة على فواتير الإصلاح (workshop_payment_allocations)
create table if not exists public.workshop_payment_allocations (
  id bigserial primary key,
  payment_id bigint not null references public.workshop_payments(id) on delete cascade,
  repair_invoice_id bigint not null references public.repair_invoices(id) on delete cascade,
  allocated_amount numeric not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_wpa_payment on public.workshop_payment_allocations(payment_id);
create index if not exists idx_wpa_invoice on public.workshop_payment_allocations(repair_invoice_id);

-- 4) تفعيل RLS
alter table public.repair_invoices enable row level security;
alter table public.workshop_payments enable row level security;
alter table public.workshop_payment_allocations enable row level security;

-- 5) سياسات RLS
drop policy if exists "Authenticated read repair invoices" on public.repair_invoices;
drop policy if exists "Authenticated insert repair invoices" on public.repair_invoices;
drop policy if exists "Authenticated update repair invoices" on public.repair_invoices;
drop policy if exists "Authenticated delete repair invoices" on public.repair_invoices;
drop policy if exists "Authenticated read workshop payments" on public.workshop_payments;
drop policy if exists "Authenticated insert workshop payments" on public.workshop_payments;
drop policy if exists "Authenticated update workshop payments" on public.workshop_payments;
drop policy if exists "Authenticated delete workshop payments" on public.workshop_payments;
drop policy if exists "Authenticated read workshop allocations" on public.workshop_payment_allocations;
drop policy if exists "Authenticated insert workshop allocations" on public.workshop_payment_allocations;
drop policy if exists "Authenticated delete workshop allocations" on public.workshop_payment_allocations;

create policy "Authenticated read repair invoices" on public.repair_invoices for select to authenticated using (true);
create policy "Authenticated insert repair invoices" on public.repair_invoices for insert to authenticated with check (true);
create policy "Authenticated update repair invoices" on public.repair_invoices for update to authenticated using (true) with check (true);
create policy "Authenticated delete repair invoices" on public.repair_invoices for delete to authenticated using (true);
create policy "Authenticated read workshop payments" on public.workshop_payments for select to authenticated using (true);
create policy "Authenticated insert workshop payments" on public.workshop_payments for insert to authenticated with check (true);
create policy "Authenticated update workshop payments" on public.workshop_payments for update to authenticated using (true) with check (true);
create policy "Authenticated delete workshop payments" on public.workshop_payments for delete to authenticated using (true);
create policy "Authenticated read workshop allocations" on public.workshop_payment_allocations for select to authenticated using (true);
create policy "Authenticated insert workshop allocations" on public.workshop_payment_allocations for insert to authenticated with check (true);
create policy "Authenticated delete workshop allocations" on public.workshop_payment_allocations for delete to authenticated using (true);

-- 6) Trigger لتحديث remaining_amount تلقائياً
create or replace function public.update_repair_invoice_remaining() returns trigger as $$
begin
  new.remaining_amount := new.total_amount - new.paid_amount;
  if new.remaining_amount <= 0 then
    new.status := 'paid';
    new.paid_amount := new.total_amount;
    new.remaining_amount := 0;
  elsif new.paid_amount > 0 and new.remaining_amount > 0 then
    new.status := 'partially_paid';
  else
    new.status := 'unpaid';
    new.paid_amount := 0;
  end if;
  new.updated_at := now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_update_repair_invoice_remaining on public.repair_invoices;
create trigger trg_update_repair_invoice_remaining before insert or update on public.repair_invoices for each row execute function public.update_repair_invoice_remaining();

-- =====================================================================
-- END OF CONSOLIDATED MIGRATION
-- =====================================================================
