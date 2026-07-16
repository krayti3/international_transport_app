-- Migration: create trip_order_documents table and trip-documents storage bucket
-- for customs documents (permits, CMR, T1/T2, etc.) attached to trip_orders.
-- Safe to re-run: all objects are guarded with if not exists / drop if exists.

-- 1. Create the trip_order_documents table.
create table if not exists public.trip_order_documents (
  id bigserial primary key,
  trip_order_id bigint not null references public.trip_orders (id) on delete cascade,
  file_name text not null,
  file_url text not null,
  file_type text not null default 'image',
  document_type text not null default 'customs',
  created_at timestamptz not null default now()
);

create index if not exists trip_order_documents_trip_order_id_idx
  on public.trip_order_documents (trip_order_id);

-- 2. Create the public 'trip-documents' storage bucket and policies.
insert into storage.buckets (id, name, public)
values ('trip-documents', 'trip-documents', true)
on conflict (id) do nothing;

drop policy if exists "Trip documents are public readable" on storage.objects;
create policy "Trip documents are public readable"
  on storage.objects for select
  using (bucket_id = 'trip-documents');

drop policy if exists "Trip documents are manageable by authenticated" on storage.objects;
create policy "Trip documents are manageable by authenticated"
  on storage.objects for all
  using (bucket_id = 'trip-documents')
  with check (bucket_id = 'trip-documents');

-- 3. Enable RLS and add permissive ALL policy on the table.
alter table public.trip_order_documents enable row level security;

drop policy if exists "Manage trip_order_documents" on public.trip_order_documents;
create policy "Manage trip_order_documents"
  on public.trip_order_documents for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.trip_order_documents to authenticated, anon;
