-- Migration: 20250719010000_clients_address_columns.sql
--
-- Adds the granular shipping-address / contact columns used by the Dart Client
-- model (lib/models/client.dart) so the app can persist client addresses.
--
-- The Client model writes nom_contact, adresse_facturation and the granular
-- shipping_address_line1..line4, shipping_city, shipping_postal_code and
-- shipping_country fields. None of these were created by any prior migration,
-- so the app's tolerant _writeRow silently strips them (PGRST204) and the
-- shipping/billing address is never recorded. This migration adds them with
-- guarded `add column if not exists` statements in the same style as the
-- sibling migrations.
--
-- Existing columns (already present, NOT recreated here): name, phone,
-- address, city, created_at, ice, shipping_address, shipping_latitude,
-- shipping_longitude, billing_address_line1..line4, billing_city,
-- billing_postal_code, billing_country, currency, email, is_active,
-- last_invoice_number, default_bank_account.

alter table public.clients
  add column if not exists nom_contact text not null default '';

alter table public.clients
  add column if not exists adresse_facturation text not null default '';

alter table public.clients
  add column if not exists shipping_address_line1 text not null default '';

alter table public.clients
  add column if not exists shipping_address_line2 text not null default '';

alter table public.clients
  add column if not exists shipping_address_line3 text not null default '';

alter table public.clients
  add column if not exists shipping_address_line4 text not null default '';

alter table public.clients
  add column if not exists shipping_city text not null default '';

alter table public.clients
  add column if not exists shipping_postal_code text not null default '';

alter table public.clients
  add column if not exists shipping_country text not null default '';

update public.system_settings set updated_at = now() where id = 1;
