-- Migration: create the advances (العُهد) table for driver trip advances.
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
