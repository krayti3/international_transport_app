-- Migration: 20250720210000_clients_invoice_with_tva.sql
-- Add invoice_with_tva column to clients table.

alter table public.clients
  add column if not exists invoice_with_tva boolean not null default false;

-- Bump cache.
update public.system_settings set updated_at = now() where id = 1;
