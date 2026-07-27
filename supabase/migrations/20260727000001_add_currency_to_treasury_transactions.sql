-- Migration: add currency tracking to treasury_transactions.
-- MAD = Morocco operations, EUR = Europe/international operations.
-- Safe to re-run: all objects are guarded with if not exists / do blocks.

alter table public.treasury_transactions
  add column if not exists currency text not null default 'MAD';

create index if not exists treasury_transactions_currency_idx
  on public.treasury_transactions (currency);

alter table public.treasury_transactions
  add constraint treasury_transactions_currency_check
  check (currency in ('MAD', 'EUR'));
