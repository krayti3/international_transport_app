-- Migration: create providers table for workshop/garage management
-- Safe to re-run: all objects are guarded with if not exists.

-- 1. Create the providers table.
create table if not exists public.providers (
  id bigserial primary key,
  name text not null,
  created_at timestamptz not null default now()
);

-- 2. Add unique constraint on name to prevent duplicates.
alter table public.providers
  add constraint if not exists providers_name_unique
  unique (name);

-- 3. Enable RLS.
alter table public.providers enable row level security;

-- 4. Drop existing policies if any, then create permissive policies.
drop policy if exists "Manage providers" on public.providers;
create policy "Manage providers"
  on public.providers for all
  using (true)
  with check (true);

-- 5. Grant API access.
grant select, insert, update, delete on table public.providers to authenticated, anon;

-- 6. Touch system_settings so dependent caches/widgets refresh.
update public.system_settings set updated_at = now() where id = 1;