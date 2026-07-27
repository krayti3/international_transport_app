-- Migration: extend trailer_maintenance with repair-specific fields
-- Safe to re-run: all objects are guarded with if not exists / do blocks

alter table public.trailer_maintenance
  add column if not exists receipt_image_url text;

alter table public.trailer_maintenance
  add column if not exists next_maintenance_date date;

alter table public.trailer_maintenance
  add column if not exists trip_order_id bigint;

alter table public.trailer_maintenance
  add column if not exists is_deleted boolean not null default false;

alter table public.trailer_maintenance
  add column if not exists currency text not null default 'MAD';

create index if not exists idx_trailer_maintenance_next_date
  on public.trailer_maintenance (next_maintenance_date);

create index if not exists idx_trailer_maintenance_trip_order
  on public.trailer_maintenance (trip_order_id);

alter table public.trailer_maintenance
  add constraint trailer_maintenance_currency_check
  check (currency in ('MAD', 'EUR'));
