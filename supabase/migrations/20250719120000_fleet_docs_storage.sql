-- Migration: create the public 'fleet_docs' storage bucket and policies so
-- the secretary/admin can upload and read fleet document images (truck/trailer
-- docs) attached to the fleet. Safe to re-run: bucket insert uses on conflict
-- do nothing; policies drop first.

insert into storage.buckets (id, name, public)
values ('fleet_docs', 'fleet_docs', true)
on conflict (id) do nothing;

drop policy if exists "Fleet docs are public readable" on storage.objects;
create policy "Fleet docs are public readable"
  on storage.objects for select
  using (bucket_id = 'fleet_docs');

drop policy if exists "Fleet docs are manageable by authenticated" on storage.objects;
create policy "Fleet docs are manageable by authenticated"
  on storage.objects for all
  using (bucket_id = 'fleet_docs')
  with check (bucket_id = 'fleet_docs');

update public.system_settings set updated_at = now() where id = 1;
