-- Migration: 20250719100000_trucks_default_trailer.sql
-- Adds the "default trailer" concept to the transport app.
-- Each truck head (public.trucks) can reference a default trailer
-- (public.trailers) via the new default_trailer_id column.
-- The column is nullable: a truck may have no default trailer.
-- The foreign key uses ON DELETE SET NULL so removing a trailer
-- does not break the referencing truck.
-- All statements are guarded to be safe to re-run.

-- 1. Add the nullable default_trailer_id column to public.trucks.
alter table public.trucks
  add column if not exists default_trailer_id integer;

-- 2. Add the foreign key constraint to public.trailers(id).
--    Postgres has no "ADD CONSTRAINT IF NOT EXISTS", so guard it in PL/pgSQL.
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'trucks_default_trailer_fkey'
      and table_schema = 'public'
      and table_name = 'trucks'
  ) then
    alter table public.trucks
      add constraint trucks_default_trailer_fkey
      foreign key (default_trailer_id)
      references public.trailers(id)
      on delete set null;
  end if;
end $$;

-- 3. Bump the cache (project convention).
update public.system_settings set updated_at = now() where id = 1;
