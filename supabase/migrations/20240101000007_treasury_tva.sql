-- Migration: create the treasury (cash flow) and TVA app-settings tables.
-- Safe to re-run: all objects are guarded with if not exists / do blocks.
--
-- Column names intentionally match the existing app models/service:
--   * TreasuryTransaction model + SupabaseService use the `type` column
--     (values: capital_injection, trip_revenue, owner_withdrawal,
--      office_expense, salary, trip_expense).
--   * AppSettings model + updateAppSettings use `is_enabled` and
--     `percentage` (the TVA rate).
--
-- If you previously ran the original SQL (columns transaction_type /
-- tva_percentage / is_tva_enabled), the rename blocks below migrate that
-- existing schema to the names the app actually expects.

-- 1. Central treasury transactions table. The current balance is NEVER stored;
--    it is computed on read as SUM(deposits) - SUM(withdrawals/expenses).
create table if not exists public.treasury_transactions (
  id bigint generated always as identity primary key,
  type text not null
    check (type in (
      'capital_injection',  -- تزويد صاحب المشروع
      'trip_revenue',       -- دخل فواتير الرحلات
      'owner_withdrawal',   -- سحب صاحب المشروع
      'office_expense',     -- مصاريف المكتب
      'salary',             -- أجور الموظفين والسائقين
      'trip_expense'        -- مصاريف الرحلات والعُهد
    )),
  amount numeric not null check (amount >= 0),
  description text,
  created_at timestamptz not null default now()
);

-- Migrate an old-schema table that used transaction_type instead of type.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'treasury_transactions'
      and column_name = 'transaction_type'
  ) then
    alter table public.treasury_transactions rename column transaction_type to type;
  end if;
end $$;

create index if not exists treasury_transactions_type_idx
  on public.treasury_transactions (type);
create index if not exists treasury_transactions_created_at_idx
  on public.treasury_transactions (created_at);

-- 2. Single-row application settings (TVA control). The CHECK constraint on
--    id forces the table to hold exactly one row.
create table if not exists public.app_settings (
  id integer primary key default 1,
  percentage numeric not null default 20,       -- نسبة الـ TVA الافتراضية (مثلاً 20%)
  is_enabled boolean not null default true,     -- تفعيل أو إلغاء الـ TVA تماماً
  constraint app_settings_single_row check (id = 1)
);

-- Migrate an old-schema table that used tva_percentage / is_tva_enabled.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_settings'
      and column_name = 'tva_percentage'
  ) then
    alter table public.app_settings rename column tva_percentage to percentage;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_settings'
      and column_name = 'is_tva_enabled'
  ) then
    alter table public.app_settings rename column is_tva_enabled to is_enabled;
  end if;
end $$;

-- Seed the single settings row on first run.
insert into public.app_settings (id, percentage, is_enabled)
values (1, 20, true)
on conflict (id) do nothing;

-- 3. Enable RLS and add permissive ALL policies (internal business app), plus
--    grant API access. Safe to re-run.
alter table public.treasury_transactions enable row level security;
alter table public.app_settings enable row level security;

drop policy if exists "Manage treasury_transactions" on public.treasury_transactions;
create policy "Manage treasury_transactions"
  on public.treasury_transactions for all
  using (true)
  with check (true);

drop policy if exists "Manage app_settings" on public.app_settings;
create policy "Manage app_settings"
  on public.app_settings for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.treasury_transactions to authenticated, anon;
grant select, insert, update, delete on table public.app_settings to authenticated, anon;
