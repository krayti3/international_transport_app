-- Migration: create truck_documents table
-- Creates the previously-missing public.truck_documents table used by the truck documents screen.

begin;

create table if not exists public.truck_documents (
  id bigserial primary key,
  truck_id integer not null references public.trucks(id) on delete cascade,
  type text not null default '',
  document_number text,
  expiry_date date not null,
  attachment_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_truck_documents_truck on public.truck_documents (truck_id);
create index if not exists idx_truck_documents_expiry on public.truck_documents (expiry_date);

alter table public.truck_documents enable row level security;

drop policy if exists "Manage truck_documents" on public.truck_documents;
create policy "Manage truck_documents" on public.truck_documents for all using (true) with check (true);

grant select, insert, update, delete on table public.truck_documents to authenticated, anon;

update public.system_settings set updated_at = now() where id = 1;

commit;
