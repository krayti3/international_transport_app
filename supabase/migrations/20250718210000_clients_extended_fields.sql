-- =====================================================================
-- Migration: extend clients table and system_settings with company-wide
-- defaults used by invoices and client forms.
-- Safe to re-run: all ALTERs are guarded with IF NOT EXISTS.
-- =====================================================================

-- =====================================================================
-- 1. Extend public.clients
-- =====================================================================

alter table public.clients
  add column if not exists ice text not null default '';          -- ICE: Moroccan tax identifier (Identifiant Commun de l'Entreprise)

alter table public.clients
  add column if not exists shipping_address text not null default ''; -- Shipping/unloading address (عنوان تفريغ/شحن البضائع)

alter table public.clients
  add column if not exists shipping_latitude double precision;    -- GPS latitude for the shipping address

alter table public.clients
  add column if not exists shipping_longitude double precision;   -- GPS longitude for the shipping address

alter table public.clients
  add column if not exists billing_address_line1 text not null default ''; -- Billing address line 1

alter table public.clients
  add column if not exists billing_address_line2 text not null default ''; -- Billing address line 2

alter table public.clients
  add column if not exists billing_address_line3 text not null default ''; -- Billing address line 3

alter table public.clients
  add column if not exists billing_address_line4 text not null default ''; -- Billing address line 4

alter table public.clients
  add column if not exists billing_city text not null default ''; -- Billing city

alter table public.clients
  add column if not exists billing_postal_code text not null default ''; -- Billing postal code

alter table public.clients
  add column if not exists billing_country text not null default ''; -- Billing country

alter table public.clients
  add column if not exists currency text not null default 'MAD';  -- Working currency (MAD = درهم, EUR = يورو, etc.)

alter table public.clients
  add column if not exists email text not null default '';        -- Customer email for correspondence

alter table public.clients
  add column if not exists is_active boolean not null default true; -- Active/inactive client flag

alter table public.clients
  add column if not exists last_invoice_number text;              -- Reference of the customer's last invoice (nullable)


-- =====================================================================
-- 2. Extend public.system_settings (single row, id = 1)
-- =====================================================================

alter table public.system_settings
  add column if not exists default_currency text not null default 'MAD'; -- Default working currency for invoices and clients

alter table public.system_settings
  add column if not exists company_country text not null default 'Maroc'; -- Default company country (Maroc, etc.)


-- =====================================================================
-- 3. Touch updated_at so the change is reflected
-- =====================================================================

update public.system_settings set updated_at = now() where id = 1;
