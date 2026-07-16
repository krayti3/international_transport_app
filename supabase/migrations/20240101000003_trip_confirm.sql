-- Migration: support the secretary "confirm trip" workflow.
-- The secretary starts a trip (advance) with status 'en_route' and may attach
-- free-form notes. Safe to re-run.

-- 1. Add a notes column to the advances (trips) table.
alter table public.advances
  add column if not exists notes text not null default '';

-- 2. Allow the 'en_route' status alongside 'pending'/'settled'. The inline
--    CHECK created by the base migration is named advances_status_check; drop
--    it (if present) and recreate with the new allowed values.
alter table public.advances drop constraint if exists advances_status_check;
alter table public.advances
  add constraint advances_status_check
  check (status in ('pending', 'en_route', 'settled'));

-- 3. Make 'en_route' the default status for new trips.
alter table public.advances alter column status set default 'en_route';
