-- Migration: 20250720100001_trailers_status_column.sql
-- Add status column to trailers table if missing.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'trailers'
      and column_name = 'status'
  ) then
    alter table public.trailers
      add column status text not null default 'active';
  end if;
end $$;

-- Bump cache.
update public.system_settings set updated_at = now() where id = 1;
