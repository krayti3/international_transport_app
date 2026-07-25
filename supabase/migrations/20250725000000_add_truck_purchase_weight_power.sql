-- Migration: add purchase date, empty weight, and fiscal power to trucks
-- Safe to re-run: all ALTERs are guarded with IF NOT EXISTS.

alter table public.trucks
  add column if not exists purchase_date date,
  add column if not exists empty_weight numeric,
  add column if not exists fiscal_power numeric;

-- Bump cache
update public.system_settings set updated_at = now() where id = 1;
