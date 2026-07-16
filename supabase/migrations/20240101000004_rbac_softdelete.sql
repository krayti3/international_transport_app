-- Migration: role-based profile data + soft delete for advances.
-- The app already has a 'users' RBAC table (id uuid, email, role, created_at)
-- managed by an earlier migration, so we extend it with a profile 'name'
-- instead of creating a duplicate 'profiles' table that would break the
-- existing role system. Safe to re-run.

-- 1. Profile name on the users table.
alter table public.users add column if not exists name text not null default '';

-- 2. Soft delete flag on advances (trips). Rows are never hard-deleted by the
--    app; "delete" flips is_deleted to true and they disappear from the
--    secretary's view while staying in the archive.
alter table public.advances
  add column if not exists is_deleted boolean not null default false;

create index if not exists advances_is_deleted_idx on public.advances (is_deleted);
