-- Add GPS location tracking columns to the trucks table
-- These columns are used by the truck tracking screen for realtime fleet monitoring
alter table public.trucks
  add column if not exists current_latitude double precision,
  add column if not exists current_longitude double precision,
  add column if not exists current_location text;

-- Enable RLS on the trucks table if not already enabled
alter table public.trucks enable row level security;

-- Allow authenticated users to read truck locations
create policy "Authenticated users can view truck locations"
  on public.trucks for select
  to authenticated
  using (true);

-- Allow authenticated users to update truck locations (for GPS tracking)
create policy "Authenticated users can update truck locations"
  on public.trucks for update
  to authenticated
  using (true)
  with check (true);
