-- Migration: add default_driver_id column to trucks
-- Safe to re-run: guarded with IF NOT EXISTS.

alter table public.trucks
  add column if not exists default_driver_id integer references public.drivers(id) on delete set null;

-- Unique constraint: one truck per default driver at most
create unique index if not exists idx_trucks_default_driver_id
  on public.trucks (default_driver_id)
  where default_driver_id is not null;

-- Bump cache
update public.system_settings set updated_at = now() where id = 1;