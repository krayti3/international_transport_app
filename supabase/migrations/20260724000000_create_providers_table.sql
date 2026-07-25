-- =============================================================================
-- Migration: create_providers_table.sql
-- Date: 2026-07-24
-- -----------------------------------------------------------------------------
-- PURPOSE:
--  1) Create shared public.providers table for workshop/provider names used in
--     maintenance expenses (truck_maintenance, trailer_maintenance, etc.).
--  2) Provide CRUD via supabase_service.dart and a management screen.
-- =============================================================================

-- 1) Create providers table if missing.
DO $$
BEGIN
  IF to_regclass('public.providers') IS NULL THEN
    CREATE TABLE public.providers (
      id   bigserial PRIMARY KEY,
      name text NOT NULL UNIQUE,
      created_at timestamptz NOT NULL DEFAULT now()
    );
  END IF;
END $$;

-- Seed default providers if empty.
INSERT INTO public.providers (name)
SELECT v FROM (VALUES
  ('ورشة خاصة'),
  ('وكالة'),
  ('مصدر محلي')
) AS t(v)
WHERE NOT EXISTS (SELECT 1 FROM public.providers);

-- RLS + permissive policy for providers.
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Manage providers" ON public.providers;
CREATE POLICY "Manage providers"
  ON public.providers FOR ALL USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.providers TO authenticated, anon;

-- Touch system_settings so dependent caches/widgets refresh.
UPDATE public.system_settings SET updated_at = now() WHERE id = 1;
