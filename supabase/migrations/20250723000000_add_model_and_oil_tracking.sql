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
