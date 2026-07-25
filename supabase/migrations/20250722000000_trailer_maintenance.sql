-- trailer_maintenance table
create table if not exists public.trailer_maintenance (
  id            serial primary key,
  trailer_id    integer not null,
  expense_type  text not null,
  description   text,
  amount        numeric not null,
  km_at_time    numeric,
  due_date      text,
  payment_status text default 'paid_by_owner',
  provider_name text,
  maintenance_date text not null,
  created_at    text default now(),
  updated_at    text default now()
);

create index if not exists idx_trailer_maintenance_trailer_id
  on public.trailer_maintenance (trailer_id);

alter table public.trailer_maintenance enable row level security;

drop policy if exists "Allow authenticated access" on public.trailer_maintenance;
create policy "Allow authenticated access"
  on public.trailer_maintenance
  for all
  to authenticated
  using (true)
  with check (true);

update public.system_settings set updated_at = now() where id = 1;
