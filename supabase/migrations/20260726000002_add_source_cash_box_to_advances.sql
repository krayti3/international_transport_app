-- Migration: add source_cash_box column to advances table for linking driver advances to cash boxes.
alter table public.advances
  add column if not exists source_cash_box text;