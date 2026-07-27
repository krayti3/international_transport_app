-- Migration: link each bank account to a cash box
-- Safe to re-run: all objects are guarded with if not exists.

ALTER TABLE public.bank_accounts
  ADD COLUMN IF NOT EXISTS cash_box_id bigint
    REFERENCES public.cash_boxes (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_bank_accounts_cash_box
  ON public.bank_accounts (cash_box_id);
