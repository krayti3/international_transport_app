-- Migration: attach a receipt image to each treasury transaction.
-- Lets the secretary photo the office-rent / salary voucher from the phone and
-- upload it to Supabase Storage; the admin can audit any expense from anywhere.
-- Safe to re-run.

alter table public.treasury_transactions
  add column if not exists receipt_url text;

create index if not exists treasury_transactions_receipt_idx
  on public.treasury_transactions (receipt_url);
