-- =====================================================================
-- Migration: add default_bank_account to clients and bank_account_type /
-- bank_info_text to invoices. Safe to re-run: all ALTERs are guarded.
-- =====================================================================

-- 1. Add default_bank_account to clients (values: 'moroccan' | 'european')
alter table public.clients
  add column if not exists default_bank_account text
  check (default_bank_account in ('moroccan', 'european'));

-- 2. Add bank_account_type and bank_info_text to invoices
alter table public.invoices
  add column if not exists bank_account_type text
  check (bank_account_type in ('moroccan', 'european'));

alter table public.invoices
  add column if not exists bank_info_text text;

-- 3. Touch updated_at so the change is reflected in row cache
update public.system_settings set updated_at = now() where id = 1;
