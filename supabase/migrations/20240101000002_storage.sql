-- Migration: create the public 'receipts' storage bucket and policies so
-- drivers/secretary can upload and read receipt photos attached to advances.
-- Safe to re-run: bucket insert uses on conflict do nothing; policies drop first.

insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

drop policy if exists "Receipts are public readable" on storage.objects;
create policy "Receipts are public readable"
  on storage.objects for select
  using (bucket_id = 'receipts');

drop policy if exists "Receipts are manageable by authenticated" on storage.objects;
create policy "Receipts are manageable by authenticated"
  on storage.objects for all
  using (bucket_id = 'receipts')
  with check (bucket_id = 'receipts');
