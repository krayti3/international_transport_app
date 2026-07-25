-- =============================================================================
-- Migration: 20250719110000_fleet_doc_type_free_text.sql
-- -----------------------------------------------------------------------------
-- PURPOSE:
--  The "document type" for fleet documents was previously a constrained foreign
--  key into public.document_categories (category_id bigint not null). This forced
--  every vehicle document to map to a fixed, predefined category.
--
--  We now allow each vehicle to have arbitrary document types, so the document
--  type becomes a FREE-TEXT field (`doc_type text`) instead of a fixed category
--  reference. This migration safely converts `category_id` (bigint, FK) into a
--  free-text `doc_type` (text, nullable) and is re-runnable (idempotent).
-- =============================================================================

-- 1) Drop the foreign key constraint on category_id (guard its existence).
DO $$
DECLARE
  v_conname text;
BEGIN
  SELECT tc.constraint_name
    INTO v_conname
    FROM information_schema.table_constraints tc
   WHERE tc.table_schema = 'public'
     AND tc.table_name   = 'fleet_documents'
     AND tc.constraint_type = 'FOREIGN KEY'
     AND tc.constraint_name = 'fleet_documents_category_id_fkey';

  IF v_conname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.fleet_documents DROP CONSTRAINT %I;', v_conname);
  END IF;
END $$;

-- 2) Rename column category_id -> doc_type (guard: only if category_id still exists).
DO $$
DECLARE
  v_has_old int;
BEGIN
  SELECT COUNT(*)
    INTO v_has_old
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name   = 'fleet_documents'
     AND column_name  = 'category_id';

  IF v_has_old = 1 THEN
    EXECUTE 'ALTER TABLE public.fleet_documents RENAME COLUMN category_id TO doc_type;';
  END IF;
END $$;

-- 3) Change doc_type column type to text (guard: only if not already text).
DO $$
DECLARE
  v_dtype text;
BEGIN
  SELECT data_type
    INTO v_dtype
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name   = 'fleet_documents'
     AND column_name  = 'doc_type';

  IF v_dtype IS NOT NULL AND v_dtype <> 'text' THEN
    EXECUTE 'ALTER TABLE public.fleet_documents ALTER COLUMN doc_type TYPE text USING doc_type::text;';
  END IF;
END $$;

-- 4) Make doc_type nullable (safe, idempotent).
ALTER TABLE public.fleet_documents ALTER COLUMN doc_type DROP NOT NULL;

-- 5) Touch system_settings so dependent caches/widgets refresh.
UPDATE public.system_settings SET updated_at = now() WHERE id = 1;
