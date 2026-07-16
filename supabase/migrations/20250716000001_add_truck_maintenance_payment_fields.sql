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
