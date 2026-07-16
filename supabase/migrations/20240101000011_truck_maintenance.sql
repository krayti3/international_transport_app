-- Migration: per-truck maintenance & depreciation expenses.
-- Records operational expenses that are deducted directly from net profit.
create table if not exists public.truck_maintenance (
  id bigserial primary key,
  truck_id bigint not null references public.trucks (id) on delete cascade,
  expense_type text not null, -- oil_change | tires | insurance | technical_inspection | depreciation | other
  description text,
  amount numeric not null default 0,
  km_at_time numeric, -- odometer reading at time of expense
  due_date date, -- for insurance, inspection etc. (next due date)
  created_at timestamp not null default now()
);

create index if not exists truck_maintenance_truck_idx
  on public.truck_maintenance (truck_id);

alter table public.truck_maintenance enable row level security;
drop policy if exists "Manage truck_maintenance" on public.truck_maintenance;
create policy "Manage truck_maintenance" on public.truck_maintenance for all using (true) with check (true);
grant select, insert, update, delete on table public.truck_maintenance to authenticated, anon;
