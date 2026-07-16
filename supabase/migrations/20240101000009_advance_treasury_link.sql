-- Migration: link each advance (عهدة) to its treasury (cash-box) postings.
-- Stores the id of the base outflow tx and the optional overspend tx so the
-- app can keep treasury_transactions in sync with advances. Safe to re-run.

alter table public.advances
  add column if not exists treasury_tx_id bigint,
  add column if not exists treasury_tx_extra_id bigint;

create index if not exists advances_treasury_tx_idx
  on public.advances (treasury_tx_id);
