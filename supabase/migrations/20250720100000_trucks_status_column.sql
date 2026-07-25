-- Migration: 20250720100000_trucks_status_column.sql
-- Add status column to trucks table if missing.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'trucks'
      and column_name = 'status'
  ) then
    alter table public.trucks
      add column status text not null default 'active';
  end if;
end $$;

-- Bump cache.
update public.system_settings set updated_at = now() where id = 1;