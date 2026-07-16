-- Document categories for fleet vehicles (trucks and trailers)
create table if not exists public.document_categories (
  id bigserial primary key,
  name text not null unique,
  created_at timestamptz default now()
);

-- Seed default document categories
insert into public.document_categories (name) values
  ('تأمين'),
  ('فحص تقني'),
  ('البطاقة الرمادية'),
  ('رخصة النقل'),
  ('شهايد مطابقة'),
  ('تأمين المسؤولية المدنية'),
  ('أخرى')
on conflict (name) do nothing;

-- Unified fleet documents table supporting both trucks and trailers
create table if not exists public.fleet_documents (
  id bigserial primary key,
  entity_type text not null check (entity_type in ('truck', 'trailer')),
  entity_id bigint not null,
  category_id bigint not null references public.document_categories(id) on delete cascade,
  document_number text,
  expiry_date date not null,
  attachment_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index for fast filtering by entity type + id
create index if not exists idx_fleet_documents_entity on public.fleet_documents (entity_type, entity_id);

-- Index for fast expiry date queries
create index if not exists idx_fleet_documents_expiry on public.fleet_documents (expiry_date);

-- Enable RLS
alter table public.document_categories enable row level security;
alter table public.fleet_documents enable row level security;

-- RLS Policies for document_categories
create policy "Authenticated users can view document categories"
  on public.document_categories for select
  to authenticated
  using (true);

create policy "Authenticated users can insert document categories"
  on public.document_categories for insert
  to authenticated
  with check (true);

-- RLS Policies for fleet_documents
create policy "Authenticated users can view fleet documents"
  on public.fleet_documents for select
  to authenticated
  using (true);

create policy "Authenticated users can insert fleet documents"
  on public.fleet_documents for insert
  to authenticated
  with check (true);

create policy "Authenticated users can update fleet documents"
  on public.fleet_documents for update
  to authenticated
  using (true)
  with check (true);

create policy "Authenticated users can delete fleet documents"
  on public.fleet_documents for delete
  to authenticated
  using (true);
