-- Migration: add_document_renewal_history
-- Adds renewal tracking fields to truck_documents:
--   * previous_expiry_date  -> keeps the old expiry before renewal
--   * renewal_cost          -> renewal cost amount
--   * renewal_currency      -> renewal cost currency
--   * renewal_notes         -> optional renewal notes / provider reference
-- Guarded to be safe to re-run.

alter table public.truck_documents
  add column if not exists previous_expiry_date date,
  add column if not exists renewal_cost numeric(10,2),
  add column if not exists renewal_currency text default 'MAD',
  add column if not exists renewal_notes text;

update public.system_settings set updated_at = now() where id = 1;
