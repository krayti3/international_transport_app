-- Migration: create the cash_boxes table and link treasury transactions to cash boxes.
-- Safe to re-run: all objects are guarded with if not exists / drop if exists.
--
-- The cash_boxes table stores the available cash boxes / accounts:
--   * owner_cash        - ??? ???? ??????
--   * bank_morocco      - ?????? ?????? ???????
--   * bank_europe       - ?????? ?????? ????????
--   * secretary_cash    - ????? ?????????
--
-- treasury_transactions gets two new nullable FK columns:
--   * cash_box_id        - the cash box this transaction belongs to
--   * related_cash_box_id- the target cash box for transfers
-- And the type CHECK constraint is expanded to include 'transfer'.

-- 1. Create the cash_boxes table.
create table if not exists public.cash_boxes (
  id bigserial primary key,
  code text unique not null,
  label text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists cash_boxes_code_idx
  on public.cash_boxes (code);

-- 2. Seed the four cash boxes.
insert into public.cash_boxes (code, label)
values
  ('owner_cash',    '??? ???? ??????'),
  ('bank_morocco',  '?????? ?????? ???????'),
  ('bank_europe',   '?????? ?????? ????????'),
  ('secretary_cash','????? ?????????')
on conflict (code) do nothing;

-- 3. Add cash_box_id and related_cash_box_id to treasury_transactions.
alter table public.treasury_transactions
  add column if not exists cash_box_id bigint
    references public.cash_boxes (id) on delete set null;

alter table public.treasury_transactions
  add column if not exists related_cash_box_id bigint
    references public.cash_boxes (id) on delete set null;

create index if not exists treasury_transactions_cash_box_id_idx
  on public.treasury_transactions (cash_box_id);

-- 4. Expand the type CHECK constraint to include 'transfer'.
do $$
declare
  v_constraint_name text;
begin
  select c.conname into v_constraint_name
  from pg_constraint c
  join pg_attribute a
    on a.attrelid = c.conrelid
   and a.attnum = any(c.conkey)
  where c.conrelid = 'public.treasury_transactions'::regclass
    and a.attname = 'type'
    and c.contype = 'c'
    and not a.attisdropped;

  if v_constraint_name is not null then
    execute format('alter table public.treasury_transactions drop constraint %I', v_constraint_name);
  end if;
end $$;

alter table public.treasury_transactions
  add constraint treasury_transactions_type_check
  check (type in (
    'capital_injection',
    'trip_revenue',
    'owner_withdrawal',
    'office_expense',
    'salary',
    'trip_expense',
    'transfer'
  ));

-- 5. Enable RLS and add permissive ALL policy (internal business app), plus
--    grant API access. Safe to re-run.
alter table public.cash_boxes enable row level security;

drop policy if exists "Manage cash_boxes" on public.cash_boxes;
create policy "Manage cash_boxes"
  on public.cash_boxes for all
  using (true)
  with check (true);

drop policy if exists "Manage treasury_transactions" on public.treasury_transactions;
create policy "Manage treasury_transactions"
  on public.treasury_transactions for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.cash_boxes to authenticated, anon;
grant select, insert, update, delete on table public.treasury_transactions to authenticated, anon;
