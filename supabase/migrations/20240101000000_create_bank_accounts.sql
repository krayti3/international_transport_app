-- Create bank_accounts table
CREATE TABLE IF NOT EXISTS bank_accounts (
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
  ('BPI France', 'FR76 3000 6000 0123 4567 8900', 'Company Name SARL', 'EUR', 'FR76 3000 6000 0123 4567 8900', 'BNPAFRPP', true)
ON CONFLICT DO NOTHING;

-- Add default_bank_account_id to clients table
ALTER TABLE clients ADD COLUMN IF NOT EXISTS default_bank_account_id UUID REFERENCES bank_accounts(id);
CREATE INDEX IF NOT EXISTS idx_clients_default_bank_account ON clients(default_bank_account_id);

-- Add bank_account_id to invoices table
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS bank_account_id UUID REFERENCES bank_accounts(id);
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS currency TEXT;
CREATE INDEX IF NOT EXISTS idx_invoices_bank_account ON invoices(bank_account_id);

-- Create function to calculate invoice amounts
CREATE OR REPLACE FUNCTION calculate_invoice_amounts(
  p_input_amount NUMERIC,
  p_input_mode TEXT,
  p_tva_rate NUMERIC
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

-- RLS policies for bank_accounts
ALTER TABLE bank_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can do everything on bank_accounts"
  ON bank_accounts FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

CREATE POLICY "Secretaries can read bank_accounts"
  ON bank_accounts FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'secretary')
    )
  );

CREATE POLICY "Secretaries can update bank_accounts"
  ON bank_accounts FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'secretary')
    )
  );