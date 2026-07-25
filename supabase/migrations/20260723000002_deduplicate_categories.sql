-- Remove duplicate rows from shared category tables, keeping the lowest id.
-- Safe to re-run.

DELETE FROM public.expense_categories a
USING public.expense_categories b
WHERE a.id > b.id
  AND a.name = b.name;

DELETE FROM public.document_categories a
USING public.document_categories b
WHERE a.id > b.id
  AND a.name = b.name;

UPDATE public.system_settings SET updated_at = now() WHERE id = 1;
