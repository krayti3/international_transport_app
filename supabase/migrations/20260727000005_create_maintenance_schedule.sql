-- Migration: create maintenance_schedule table for periodic maintenance planning
-- Safe to re-run: all objects are guarded with if not exists / do blocks

create table if not exists public.maintenance_schedule (
  id bigserial primary key,
  vehicle_type text not null check (vehicle_type in ('truck', 'trailer')),
  vehicle_id bigint not null,
  task_type text not null,
  description text,
  scheduled_date date not null,
  due_km numeric,
  status text not null default 'pending' check (status in ('pending', 'completed', 'skipped', 'overdue')),
  assigned_to text,
  estimated_cost numeric,
  notification_sent boolean not null default false,
  completed_at timestamp,
  completed_km numeric,
  actual_cost numeric,
  notes text,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_maintenance_schedule_vehicle
  on public.maintenance_schedule (vehicle_type, vehicle_id);

create index if not exists idx_maintenance_schedule_status
  on public.maintenance_schedule (status, scheduled_date);

alter table public.maintenance_schedule enable row level security;

drop policy if exists "Manage maintenance_schedule" on public.maintenance_schedule;
create policy "Manage maintenance_schedule"
  on public.maintenance_schedule for all using (true) with check (true);

grant select, insert, update, delete on table public.maintenance_schedule to authenticated, anon;

update public.system_settings set updated_at = now() where id = 1;
