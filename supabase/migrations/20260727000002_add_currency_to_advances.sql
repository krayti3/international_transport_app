-- Migration: add currency column to advances table for trip currency tracking.
alter table public.advances
  add column if not exists currency text not null default 'MAD';

create index if not exists advances_currency_idx
  on public.advances (currency);

alter table public.advances
  add constraint advances_currency_check
  check (currency in ('MAD', 'EUR'));
