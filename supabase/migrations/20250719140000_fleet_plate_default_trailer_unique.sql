-- Migration: 20250719140000_fleet_plate_default_trailer_unique.sql
-- Enforces uniqueness rules for the fleet:
--   1. truck plate_number must be unique across trucks
--   2. trailer plate_number must be unique across trailers
--   3. a trailer can be the default_trailer_id of at most one truck
--      (NULLs are allowed multiple times since a truck may have no default trailer)
-- All statements are guarded to be safe to re-run.
-- IMPORTANT: If duplicate plates exist, this migration will fail with a clear
--            message. Please clean duplicates in Supabase Dashboard > Table
--            Editor before re-running.

-- 1. Guarded check: fail fast if duplicate truck plates exist.
do $$
begin
  if exists (
    select plate_number
    from public.trucks
    group by plate_number
    having count(*) > 1
  ) then
    raise exception 'Cannot add unique constraint on trucks.plate_number: duplicate plate numbers found. Please clean duplicates first.';
  end if;
end $$;

-- 2. Guarded check: fail fast if duplicate trailer plates exist.
do $$
begin
  if exists (
    select plate_number
    from public.trailers
    group by plate_number
    having count(*) > 1
  ) then
    raise exception 'Cannot add unique constraint on trailers.plate_number: duplicate plate numbers found. Please clean duplicates first.';
  end if;
end $$;

-- 3. Add unique constraint on trucks.plate_number.
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'trucks_plate_number_key'
      and table_schema = 'public'
      and table_name = 'trucks'
  ) then
    alter table public.trucks
      add constraint trucks_plate_number_key
      unique (plate_number);
  end if;
end $$;

-- 4. Add unique constraint on trailers.plate_number.
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'trailers_plate_number_key'
      and table_schema = 'public'
      and table_name = 'trailers'
  ) then
    alter table public.trailers
      add constraint trailers_plate_number_key
      unique (plate_number);
  end if;
end $$;

-- 5. Add unique constraint on trucks.default_trailer_id.
--    Postgres allows multiple NULLs in a UNIQUE column, so trucks without a
--    default trailer are not affected.
--    Guarded: only run if the column actually exists (earlier migration may
--    not have been applied yet).
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'trucks'
      and column_name = 'default_trailer_id'
  ) then
    if not exists (
      select 1 from information_schema.table_constraints
      where constraint_name = 'trucks_default_trailer_id_key'
        and table_schema = 'public'
        and table_name = 'trucks'
    ) then
      alter table public.trucks
        add constraint trucks_default_trailer_id_key
        unique (default_trailer_id);
    end if;
  end if;
end $$;

-- 6. Bump the cache (project convention).
update public.system_settings set updated_at = now() where id = 1;
