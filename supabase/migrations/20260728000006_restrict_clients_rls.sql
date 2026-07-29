-- Migration: tighten clients RLS so drivers only see their own trip clients
-- Safe to re-run: all DROP POLICYs are guarded with IF EXISTS.

-- 1. Drop the old catch-all policy.
drop policy if exists "Clients are manageable by authenticated" on public.clients;

-- 2. Admin + secretary can manage all clients.
drop policy if exists "Admins and secretaries can manage clients" on public.clients;
create policy "Admins and secretaries can manage clients"
  on public.clients
  for all
  using (
    coalesce(
      (select role from public.users where id = auth.uid()),
      ''
    ) in ('admin', 'secretary')
  )
  with check (
    coalesce(
      (select role from public.users where id = auth.uid()),
      ''
    ) in ('admin', 'secretary')
  );

-- 3. Drivers can only read clients that are in their own trips.
drop policy if exists "Drivers can view their own trip clients" on public.clients;
create policy "Drivers can view their own trip clients"
  on public.clients
  for select
  using (
    exists (
      select 1
      from public.trip_orders
      where trip_orders.client_id = clients.id
        and trip_orders.driver_id = (
          select d.id
          from public.drivers d
          where d.user_id = auth.uid()
          limit 1
        )
    )
  );

-- 4. Keep API access grants.
grant select on table public.clients to authenticated, anon;
grant insert, update, delete on table public.clients to authenticated;
