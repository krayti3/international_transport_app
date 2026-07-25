-- =============================================================================
-- Migration: restore_document_and_expense_categories.sql
-- Date: 2026-07-23
-- -----------------------------------------------------------------------------
-- PURPOSE:
--  1) Re-create public.document_categories (was removed by free-text migration).
--  2) Create shared public.expense_categories for repair/ maintenance expense types.
--  3) Add theme_mode column to public.users for theme preference persistence.
-- =============================================================================

-- 1) Re-create document_categories if missing (idempotent).
DO $$
BEGIN
  IF to_regclass('public.document_categories') IS NULL THEN
    CREATE TABLE public.document_categories (
      id   bigserial PRIMARY KEY,
      name text NOT NULL UNIQUE,
      created_at timestamptz NOT NULL DEFAULT now()
    );
  END IF;
END $$;

-- Seed default document categories if empty.
INSERT INTO public.document_categories (name)
SELECT v FROM (VALUES
  ('بطلان'),
  ('تأمين'),
  ('رخصة'),
  ('تراقب')
) AS t(v)
WHERE NOT EXISTS (SELECT 1 FROM public.document_categories);

-- RLS + permissive policy for document_categories.
ALTER TABLE public.document_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Manage document_categories" ON public.document_categories;
CREATE POLICY "Manage document_categories"
  ON public.document_categories FOR ALL USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_categories TO authenticated, anon;


-- 2) Create expense_categories (shared across all users).
DO $$
BEGIN
  IF to_regclass('public.expense_categories') IS NULL THEN
    CREATE TABLE public.expense_categories (
      id   bigserial PRIMARY KEY,
      name text NOT NULL UNIQUE,
      created_at timestamptz NOT NULL DEFAULT now()
    );
  END IF;
END $$;

-- Seed default expense categories if empty.
INSERT INTO public.expense_categories (name)
SELECT v FROM (VALUES
  ('زيت'),
  ('إطارات'),
  ('تأمين'),
  ('فحص تقني'),
  ('إهلاك'),
  ('أخرى')
) AS t(v)
WHERE NOT EXISTS (SELECT 1 FROM public.expense_categories);

-- RLS + permissive policy for expense_categories.
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Manage expense_categories" ON public.expense_categories;
CREATE POLICY "Manage expense_categories"
  ON public.expense_categories FOR ALL USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expense_categories TO authenticated, anon;


-- 3) Add theme_mode to public.users (idempotent).
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS theme_mode text NOT NULL DEFAULT 'system'
  CHECK (theme_mode IN ('light','dark','system'));

-- Touch system_settings so dependent caches/widgets refresh.
UPDATE public.system_settings SET updated_at = now() WHERE id = 1;
