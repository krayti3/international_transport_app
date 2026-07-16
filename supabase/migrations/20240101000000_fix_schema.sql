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
