-- 1. Create bank_accounts table
CREATE TABLE bank_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_holder TEXT NOT NULL,
  currency TEXT NOT NULL CHECK (currency IN ('MAD', 'EUR')),
  iban TEXT,
  swift_code TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed initial data
INSERT INTO bank_accounts (bank_name, account_number, account_holder, currency, iban, swift_code, is_active)
VALUES 
  ('Attijariwafa Bank', '001 123 456789012', 'Company Name SARL', 'MAD', 'MA64 0011 1234 5678 9012', 'BCMAMAMC', true),
  ('BPI France', 'FR76 3000 6000 0123 4567 8900', 'Company Name SARL', 'EUR', 'FR76 3000 6000 0123 4567 8900', 'BNPAFRPP', true);

-- 2. Add default_bank_account_id to clients table
ALTER TABLE clients ADD COLUMN default_bank_account_id UUID REFERENCES bank_accounts(id);
CREATE INDEX idx_clients_default_bank_account ON clients(default_bank_account_id);

-- 3. Add bank_account_id to invoices table
ALTER TABLE invoices ADD COLUMN bank_account_id UUID REFERENCES bank_accounts(id);

-- Add a trigger to auto-populate currency from the linked bank account
CREATE OR REPLACE FUNCTION set_invoice_currency()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.bank_account_id IS NOT NULL THEN
    SELECT currency INTO NEW.currency
    FROM bank_accounts
    WHERE id = NEW.bank_account_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_invoice_currency
BEFORE INSERT OR UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION set_invoice_currency();

CREATE INDEX idx_invoices_bank_account ON invoices(bank_account_id);

-- 4. Create a Supabase Database Function for TVA calculations
CREATE OR REPLACE FUNCTION calculate_invoice_amounts(
  p_input_amount NUMERIC,
  p_input_mode TEXT,  -- 'HT' or 'TTC'
  p_tva_rate NUMERIC   -- e.g., 20.0
)
RETURNS TABLE (
  ht_amount NUMERIC,
  tva_amount NUMERIC,
  ttc_amount NUMERIC
) AS $$
DECLARE
  v_ht NUMERIC;
  v_tva NUMERIC;
  v_ttc NUMERIC;
BEGIN
  IF p_input_mode = 'HT' THEN
    v_ht := p_input_amount;
    v_tva := v_ht * (p_tva_rate / 100);
    v_ttc := v_ht + v_tva;
  ELSIF p_input_mode = 'TTC' THEN
    v_ttc := p_input_amount;
    v_ht := v_ttc / (1 + (p_tva_rate / 100));
    v_tva := v_ht * (p_tva_rate / 100);
  ELSE
    RAISE EXCEPTION 'Invalid input mode: %', p_input_mode;
  END IF;
  
  RETURN QUERY SELECT v_ht, v_tva, v_ttc;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 5. Add RLS policies for bank_accounts table
ALTER TABLE bank_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin full access" ON bank_accounts
  FOR ALL
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));

CREATE POLICY "Secretary read and update" ON bank_accounts
  FOR SELECT, UPDATE
  USING (is_secretary(auth.uid()));

CREATE POLICY "Authenticated user read access" ON bank_accounts
  FOR SELECT
  USING (auth.role() = 'authenticated');
