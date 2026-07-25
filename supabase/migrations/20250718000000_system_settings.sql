-- Migration: create system_settings single-row table and company_assets storage bucket
-- Safe to re-run: all objects are guarded with if not exists / drop if exists / on conflict do nothing.

-- 1. Create the system_settings table (single row for company-wide configuration)
create table if not exists public.system_settings (
  id int8 primary key default 1,
  company_name text not null default '',
  head_office_address text not null default '',
  invoice_description text not null default '',
  bank_account_ma text not null default '',
  bank_account_eu text not null default '',
  phone_ma text not null default '',
  phone_eu text not null default '',
  contact_email text not null default '',
  logo_url text not null default '',
  updated_at timestamptz not null default now()
);

-- 2. Seed the single row if it does not exist
insert into public.system_settings (id)
values (1)
on conflict (id) do nothing;

-- 3. Enable Row Level Security on system_settings
alter table public.system_settings enable row level security;

-- 4. RLS Policies
drop policy if exists "System settings are readable by authenticated" on public.system_settings;
create policy "System settings are readable by authenticated"
  on public.system_settings
  for select
  using (auth.role() = 'authenticated');

drop policy if exists "System settings are manageable by admin" on public.system_settings;
create policy "System settings are manageable by admin"
  on public.system_settings
  for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- 5. Grant permissions
grant select on public.system_settings to authenticated, anon;
grant insert, update, delete on public.system_settings to authenticated;

-- 6. Create the public company_assets storage bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('company_assets', 'company_assets', true, 5242880, array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'])
on conflict (id) do nothing;

-- 7. Storage RLS policies for company_assets
drop policy if exists "Company assets are public readable" on storage.objects;
create policy "Company assets are public readable"
  on storage.objects for select
  using (bucket_id = 'company_assets');

drop policy if exists "Company assets are manageable by authenticated" on storage.objects;
create policy "Company assets are manageable by authenticated"
  on storage.objects for all
  using (bucket_id = 'company_assets')
  with check (bucket_id = 'company_assets');
