-- Link drivers to auth users so the driver app can auto-detect
-- which driver record belongs to the logged-in user.
alter table public.drivers
  add column if not exists user_id uuid references auth.users(id) on delete set null;

create index if not exists drivers_user_id_idx
  on public.drivers (user_id);
