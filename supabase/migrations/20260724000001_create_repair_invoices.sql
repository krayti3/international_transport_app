-- جداول فواتير إصلاح الورش والدفعات الخاصة بها
-- يُطبَّق مبدأ FIFO (أقدم فاتورة أولاً) لتسوية الديون

-- 1) جدول فواتير الإصلاح (repair_invoices)
-- يُمثّل كل سطر فاتورة إصلاح صادرة من ورشة لأحد المركبات
create table if not exists public.repair_invoices (
  id bigserial primary key,
  workshop_id text not null,
  vehicle_id text,
  vehicle_type text check (vehicle_type in ('truck', 'trailer')),
  invoice_number text not null,
  total_amount numeric not null default 0,
  paid_amount numeric not null default 0,
  remaining_amount numeric generated always as (total_amount - paid_amount) stored,
  status text not null default 'unpaid' check (status in ('unpaid', 'partially_paid', 'paid')),
  date timestamp not null default now(),
  description text,
  payment_method text,
  payment_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_repair_invoices_workshop on public.repair_invoices(workshop_id);
create index if not exists idx_repair_invoices_vehicle on public.repair_invoices(vehicle_id);
create index if not exists idx_repair_invoices_status on public.repair_invoices(status);
create index if not exists idx_repair_invoices_date on public.repair_invoices(date);
create unique index if not exists idx_repair_invoices_number on public.repair_invoices(invoice_number);

-- 2) جدول دفعات تسوية فواتير الورش (workshop_payments)
-- يُسجَّل هنا كل دفعة (نقداً، شيك، تحويل) تُقدَّم لتسوية فواتير الورش
create table if not exists public.workshop_payments (
  id bigserial primary key,
  workshop_id text not null,
  amount numeric not null,
  method text not null,
  ref text,
  vehicle_type text check (vehicle_type in ('truck', 'trailer')),
  vehicle_id text,
  payment_date timestamp not null default now(),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_workshop_payments_workshop on public.workshop_payments(workshop_id);
create index if not exists idx_workshop_payments_date on public.workshop_payments(payment_date);

-- 3) جدول توزيع الدفعة على فواتير الإصلاح (workshop_payment_allocations)
-- العلاقة بين الدفعة والفواتير Many-to-Many
create table if not exists public.workshop_payment_allocations (
  id bigserial primary key,
  payment_id bigint not null references public.workshop_payments(id) on delete cascade,
  repair_invoice_id bigint not null references public.repair_invoices(id) on delete cascade,
  allocated_amount numeric not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_wpa_payment on public.workshop_payment_allocations(payment_id);
create index if not exists idx_wpa_invoice on public.workshop_payment_allocations(repair_invoice_id);

-- 4) تفعيل RLS
alter table public.repair_invoices enable row level security;
alter table public.workshop_payments enable row level security;
alter table public.workshop_payment_allocations enable row level security;

-- 5) سياسات RLS للسماح بالقراءة والكتابة للمستخدمين الموثقين
create policy "Authenticated read repair invoices"
  on public.repair_invoices for select
  to authenticated using (true);

create policy "Authenticated insert repair invoices"
  on public.repair_invoices for insert
  to authenticated with check (true);

create policy "Authenticated update repair invoices"
  on public.repair_invoices for update
  to authenticated using (true) with check (true);

create policy "Authenticated delete repair invoices"
  on public.repair_invoices for delete
  to authenticated using (true);

create policy "Authenticated read workshop payments"
  on public.workshop_payments for select
  to authenticated using (true);

create policy "Authenticated insert workshop payments"
  on public.workshop_payments for insert
  to authenticated with check (true);

create policy "Authenticated update workshop payments"
  on public.workshop_payments for update
  to authenticated using (true) with check (true);

create policy "Authenticated delete workshop payments"
  on public.workshop_payments for delete
  to authenticated using (true);

create policy "Authenticated read workshop allocations"
  on public.workshop_payment_allocations for select
  to authenticated using (true);

create policy "Authenticated insert workshop allocations"
  on public.workshop_payment_allocations for insert
  to authenticated with check (true);

create policy "Authenticated delete workshop allocations"
  on public.workshop_payment_allocations for delete
  to authenticated using (true);

-- 6) دالة مساعدة لتحديث remaining_amount تلقائياً عند تغيير paid_amount
create or replace function public.update_repair_invoice_remaining()
returns trigger as $$
begin
  new.remaining_amount := new.total_amount - new.paid_amount;
  if new.remaining_amount <= 0 then
    new.status := 'paid';
    new.paid_amount := new.total_amount;
    new.remaining_amount := 0;
  elsif new.paid_amount > 0 and new.remaining_amount > 0 then
    new.status := 'partially_paid';
  else
    new.status := 'unpaid';
    new.paid_amount := 0;
  end if;
  new.updated_at := now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_update_repair_invoice_remaining on public.repair_invoices;
create trigger trg_update_repair_invoice_remaining
before insert or update on public.repair_invoices
for each row execute function public.update_repair_invoice_remaining();
