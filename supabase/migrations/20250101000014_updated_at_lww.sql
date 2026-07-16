-- =====================================================================
-- 15. 20250101000014_updated_at_lww.sql
-- =====================================================================
--
-- Migration: add updated_at timestamps + auto-update triggers for
-- Last-Write-Wins (LWW) conflict resolution.
--
-- Strategy: every UPDATE sets updated_at = now() automatically via
-- a BEFORE UPDATE trigger. When the app later syncs offline changes
-- it can compare its stored updated_at with the server row; the
-- newest timestamp wins. The app's update helpers include
-- "WHERE updated_at <= :stamp" so stale writes are silently ignored.
--
-- Safe to re-run: every statement is guarded with IF NOT EXISTS /
-- DROP IF EXISTS. Existing rows get created_at as a fallback for
-- updated_at.

-- 1. Reconcile columns on every mutable table
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'clients', 'trip_orders', 'invoices', 'treasury_transactions',
    'advances', 'drivers', 'trucks', 'truck_maintenance',
    'trip_order_documents', 'documents', 'app_settings'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now()', t);
      EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now()', t);
      -- Backfill: newly added column -> use created_at fallback
      EXECUTE format('UPDATE public.%I SET updated_at = created_at WHERE updated_at IS NULL', t);
    END IF;
  END LOOP;
END $$;

-- 2. Generic trigger function
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- 3. Attach trigger to every mutable table
DO $$
DECLARE
  t text;
  sql text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'clients', 'trip_orders', 'invoices', 'treasury_transactions',
    'advances', 'drivers', 'trucks', 'truck_maintenance',
    'trip_order_documents', 'documents', 'app_settings'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      sql := format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
      EXECUTE sql;
      sql := format(
        'CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()',
        t
      );
      EXECUTE sql;
    END IF;
  END LOOP;
END $$;

-- 4. Index updated_at for faster conflict checks
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'clients', 'trip_orders', 'invoices', 'treasury_transactions',
    'advances', 'drivers', 'trucks', 'truck_maintenance',
    'trip_order_documents', 'documents', 'app_settings'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('CREATE INDEX IF NOT EXISTS %I_updated_at_idx ON public.%I (updated_at)', t, t);
    END IF;
  END LOOP;
END $$;
