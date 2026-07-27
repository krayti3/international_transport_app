-- Migration: create cash_box_operations table for allowed financial operations per cash box.
-- Each row represents one operation allowed on a given cash box.
-- The special code 'all' means every operation is permitted.

create table if not exists public.cash_box_operations (
  cash_box_id bigint not null references public.cash_boxes (id) on delete cascade,
  operation_code text not null,
  created_at timestamptz not null default now(),
  primary key (cash_box_id, operation_code)
);

create index if not exists cash_box_operations_cash_box_id_idx
  on public.cash_box_operations (cash_box_id);

insert into public.cash_box_operations (cash_box_id, operation_code)
select id, 'all' from public.cash_boxes
on conflict (cash_box_id, operation_code) do nothing;

alter table public.cash_box_operations enable row level security;

drop policy if exists "Manage cash_box_operations" on public.cash_box_operations;
create policy "Manage cash_box_operations"
  on public.cash_box_operations for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.cash_box_operations to authenticated, anon;
