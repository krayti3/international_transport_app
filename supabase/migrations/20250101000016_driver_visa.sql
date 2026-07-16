-- Add visa tracking columns to the drivers table
-- These columns are used by the visa tracking screen for driver visa management

alter table public.drivers
  add column if not exists visa_number text,
  add column if not exists visa_expiry_date date,
  add column if not exists has_valid_visa boolean default false;

-- Enable RLS on the drivers table if not already enabled
alter table public.drivers enable row level security;

-- Allow authenticated users to read driver visa data
create policy "Authenticated users can view driver visa data"
  on public.drivers for select
  to authenticated
  using (true);

-- Allow authenticated users to update driver visa data
create policy "Authenticated users can update driver visa data"
  on public.drivers for update
  to authenticated
  using (true)
  with check (true);
