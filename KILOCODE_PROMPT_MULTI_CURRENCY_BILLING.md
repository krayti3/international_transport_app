# Kilocode Prompt: Multi-Currency Billing System with Dynamic Bank Accounts & HT/TTC Calculations

## Context
You are working on an existing Flutter + Supabase international transport management application. The app uses:
- **Flutter** with **flutter_bloc (Cubit)** for feature state management (BlocConsumer pattern)
- **Provider** only for cross-widget state (ThemeProvider, LocaleProvider)
- **Supabase** (PostgreSQL) as backend with Row Level Security (RLS)
- **Repository Pattern** — 13 repositories in `lib/repositories/` injected via `RepositoryProvider`
- Hand-written Dart models with `fromMap`/`toMap`/`copyWith`
- Existing tables: `clients`, `invoices`, `payments`, `payment_invoice_allocations`, `app_settings`, `trip_orders`, `users`, `bank_accounts`
- **No ORM** (no freezed, no json_serializable)
- All monetary values use `Decimal` type (from `decimal` package)
- The app supports Arabic/French/English localization

## Business Requirements

### 1. Multi-Currency Bank Accounts
The company owner maintains TWO bank accounts:
- **Account 1 (Morocco):** Currency = MAD (Moroccan Dirham), for clients residing in Morocco
- **Account 2 (Europe):** Currency = EUR (Euro), for clients residing in Europe

**Requirements:**
- Each invoice must be associated with a specific bank account
- When creating an invoice, the system must automatically select the client's default bank account
- The secretary/admin must have the ability to **override** the bank account selection before saving the invoice
- The selected bank account determines:
  - The currency displayed on the invoice
  - Where the payment is tracked

### 2. HT vs TTC Input Modes
Invoices can be entered in two modes:
- **HT (Hors Tax):** Amount entered excluding tax, TVA is calculated and added
- **TTC (Toutes Taxes Comprises):** Amount entered including tax, HT is derived by removing TVA

**Requirements:**
- The TVA (VAT) rate is **dynamic** and stored in `app_settings` table (column: `percentage`)
- The system must support switching between HT and TTC input modes on the same form
- When the mode changes, the displayed amounts must update instantly
- All calculations must use **exact decimal arithmetic** (no floating-point errors)

### 3. Calculation Equations

**TVA Rate:** Retrieved from `app_settings.percentage` (e.g., 20 for 20%)

**If input mode is HT:**
```
TTC = HT + (HT * TVA / 100)
HT = TTC / (1 + TVA / 100)
```

**If input mode is TTC:**
```
HT = TTC / (1 + TVA / 100)
TVA = HT * (TVA / 100)
TTC = HT + TVA
```

**Critical:** All calculations must use `Decimal` type (from `decimal` package), NOT `double`.

## Implementation Tasks

### Task 1: Database Schema Changes (Supabase)

Create a new migration file that:

1. **Creates `bank_accounts` table:**
```sql
CREATE TABLE bank_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_name TEXT NOT NULL,           -- e.g., "Attijariwafa Bank", "BPI France"
  account_number TEXT NOT NULL,
  account_holder TEXT NOT NULL,
  currency TEXT NOT NULL CHECK (currency IN ('MAD', 'EUR')),
  iban TEXT,
  swift_code TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed initial data (Morocco + Europe accounts)
INSERT INTO bank_accounts (bank_name, account_number, account_holder, currency, iban, swift_code, is_active)
VALUES 
  ('Attijariwafa Bank', '001 123 456789012', 'Company Name SARL', 'MAD', 'MA64 0011 1234 5678 9012', 'BCMAMAMC', true),
  ('BPI France', 'FR76 3000 6000 0123 4567 8900', 'Company Name SARL', 'EUR', 'FR76 3000 6000 0123 4567 8900', 'BNPAFRPP', true);
```

2. **Add `default_bank_account_id` to `clients` table:**
```sql
ALTER TABLE clients ADD COLUMN default_bank_account_id UUID REFERENCES bank_accounts(id);
-- Create index
CREATE INDEX idx_clients_default_bank_account ON clients(default_bank_account_id);
```

3. **Add `bank_account_id` to `invoices` table:**
```sql
ALTER TABLE invoices ADD COLUMN bank_account_id UUID REFERENCES bank_accounts(id);
ALTER TABLE invoices ADD COLUMN currency TEXT GENERATED ALWAYS AS (
  (SELECT currency FROM bank_accounts WHERE id = bank_account_id)
) STORED;
-- Or add a trigger to auto-populate currency from the linked bank account
CREATE INDEX idx_invoices_bank_account ON invoices(bank_account_id);
```

4. **Create a Supabase Database Function for TVA calculations:**
```sql
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
```

5. **Add RLS policies for `bank_accounts` table:**
- Admin: full access
- Secretary: read + update
- Driver: no access

### Task 2: Dart Models

Create the following model files following the existing pattern (hand-written `fromMap`/`toMap`/`copyWith`/`==`/`hashCode`):

1. **`lib/models/bank_account.dart`**
   - Fields: `id`, `bankName`, `accountNumber`, `accountHolder`, `currency`, `iban`, `swiftCode`, `isActive`, `createdAt`, `updatedAt`
   - Use `String` for `id` (UUID)
   - Implement `copyWith`, `fromMap`, `toMap`
   - Add a getter: `String get displayName => '$bankName ($currency)'`

2. **Update `lib/models/invoice.dart`**
   - Add fields: `bankAccountId` (String?), `currency` (String?), `inputMode` (String: 'HT' or 'TTC'), `htAmount` (double? or Decimal?), `tvaRate` (double?), `tvaAmount` (double?), `ttcAmount` (double?)
   - **CRITICAL:** All monetary fields must use `Decimal` type, not `double`
   - Add `fromMap`/`toMap` updates to handle new fields
   - Add getters for calculated values

3. **Update `lib/models/client.dart`**
   - Add field: `defaultBankAccountId` (String?)

### Task 3: Calculation Engine (Dart)

Create **`lib/services/calculation_engine.dart`** with the following requirements:

1. **Add `decimal` package to `pubspec.yaml`** (if not already present)
   ```yaml
   dependencies:
     decimal: ^2.3.0
   ```

2. **Create `InvoiceCalculation` class:**
   ```dart
   class InvoiceCalculation {
     final Decimal htAmount;
     final Decimal tvaAmount;
     final Decimal ttcAmount;
     final Decimal tvaRate;
     final String inputMode; // 'HT' or 'TTC'
     
     InvoiceCalculation({
       required this.htAmount,
       required this.tvaAmount,
       required this.ttcAmount,
       required this.tvaRate,
       required this.inputMode,
     });
     
   factory InvoiceCalculation.fromInput({
     required Decimal inputAmount,
     required String inputMode,
     required Decimal tvaRate,
   }) {
     // Implement HT <-> TTC conversion logic here
   }
   }
   ```

3. **Create `CalculationEngine` class:**
   ```dart
   class CalculationEngine {
     static InvoiceCalculation calculate({
       required Decimal amount,
       required String inputMode, // 'HT' or 'TTC'
       required Decimal tvaRate,
     }) {
       // Core calculation logic using Decimal arithmetic
     }
     
     static Decimal calculateTVA(Decimal htAmount, Decimal tvaRate) {
       // htAmount * tvaRate / 100
     }
     
     static Decimal calculateTTC(Decimal htAmount, Decimal tvaRate) {
       // htAmount + calculateTVA(htAmount, tvaRate)
     }
     
     static Decimal calculateHTFromTTC(Decimal ttcAmount, Decimal tvaRate) {
       // ttcAmount / (1 + tvaRate / 100)
     }
     
     static Decimal roundToCurrency(Decimal amount, int decimals) {
       // Round to 2 or 3 decimal places based on currency
     }
   }
   ```

**Important:** All calculations must use `Decimal` to avoid floating-point precision errors. Import `package:decimal/decimal.dart`.

### Task 4: Repository Updates

Update **`lib/repositories/invoice_repository.dart`** with the following methods:

1. **Add bank account CRUD methods:**
   ```dart
   Future<List<BankAccount>> getBankAccounts() async
   Future<BankAccount?> getBankAccountById(String id) async
   Future<BankAccount> createBankAccount(BankAccount account) async
   Future<BankAccount> updateBankAccount(BankAccount account) async
   Future<void> deleteBankAccount(String id) async
   ```

2. **Add invoice creation with bank account:**
   ```dart
   Future<Invoice> createInvoice({
     required String clientId,
     required Decimal amount,
     required String inputMode, // 'HT' or 'TTC'
     String? bankAccountId, // If null, use client's default
     DateTime? issueDate,
     DateTime? dueDate,
   }) async
   ```

   Logic:
   - If `bankAccountId` is null, fetch client's `default_bank_account_id`
   - If client has no default, throw error or prompt user
   - Get TVA rate from `app_settings`
   - Calculate HT/TVA/TTC using `CalculationEngine`
   - Create invoice with all calculated fields

3. **Update `computeInvoiceTotals`** to use Decimal:
   - Change return type to use `Decimal` instead of `double`
   - Use `CalculationEngine` for all TVA computations

4. **Add method to update client's default bank account:**
   ```dart
   Future<void> updateClientDefaultBankAccount(String clientId, String bankAccountId) async
   ```

### Task 5: UI Implementation

Update/create the following screens following the existing cubit pattern (`StatelessWidget` + `BlocConsumer`):

1. **Update `lib/screens/invoice_form_screen.dart`** (or create if it doesn't exist):
   - Add a **HT/TTC toggle switch** at the top of the form
   - Add a **Bank Account dropdown** showing: `bankName (currency)` format
   - When toggling HT/TTC, recalculate amounts in real-time
   - When changing bank account, update currency display
   - Show three amount fields:
     - **HT Amount** (editable if mode is HT, read-only if TTC)
     - **TVA Rate** (editable, fetched from app_settings)
     - **TVA Amount** (calculated, read-only)
     - **TTC Amount** (editable if mode is TTC, read-only if HT)
   - Add validation: amounts must be > 0
   - On save, dispatch `CreateInvoiceEvent` to `InvoicesCubit`

2. **Update `lib/screens/clients_screen.dart`** (or create client_form_screen.dart):
   - Add field to select default bank account when creating/editing a client
   - Show dropdown with bank accounts grouped by currency or just list all

3. **Create `lib/screens/bank_accounts_screen.dart`** (admin only):
   - List all bank accounts
   - Add/Edit/Delete bank accounts
   - Show currency badge (MAD or EUR)
   - Admin-only access (use existing `RoleGuard` widget)

4. **Update PDF generation in `lib/services/pdf_service.dart`:**
   - Show selected bank account details on the invoice
   - Show currency symbol (DH for MAD, € for EUR)
   - Display amounts in the correct currency

### Task 6: State Management

Since the app uses `flutter_bloc` (Cubit pattern), create:

1. **`lib/cubits/invoice_cubit.dart`** + **`lib/cubits/invoice_state.dart`**:
   ```dart
   class InvoiceCubit extends Cubit<InvoiceState> {
     final InvoiceRepository _invoiceRepository;
     final BankAccountRepository _bankAccountRepository;
     final SettingsRepository _settingsRepository;

     InvoiceCubit(this._invoiceRepository, this._bankAccountRepository, this._settingsRepository)
         : super(InvoiceInitial());

     BankAccount? _selectedBankAccount;
     String _inputMode = 'HT';
     Decimal _tvaRate = Decimal.zero;
     InvoiceCalculation? _calculation;

     // Getters
     BankAccount? get selectedBankAccount => _selectedBankAccount;
     String get inputMode => _inputMode;
     Decimal get tvaRate => _tvaRate;
     InvoiceCalculation? get calculation => _calculation;

     // Methods
     void setInputMode(String mode) {
       _inputMode = mode;
       _recalculate();
       emit(state.copyWith(inputMode: mode));
     }

     void setBankAccount(BankAccount? account) {
       _selectedBankAccount = account;
       emit(state.copyWith(selectedBankAccount: account));
     }

     void setTvaRate(Decimal rate) {
       _tvaRate = rate;
       _recalculate();
       emit(state.copyWith(tvaRate: rate));
     }

     void _recalculate() {
       // Recalculate invoice amounts based on current input
     }
   }
   ```

2. **Update `lib/main.dart`** to add `InvoiceCubit` to the `MultiBlocProvider` list.

### Task 7: Migration & Data Consistency

1. **Backfill existing invoices:**
   - For all existing invoices, assign a default bank account based on client location
   - If client is in Morocco → use MAD account
   - If client is in Europe → use EUR account
   - If unknown → use MAD as default
   - Set currency field accordingly

2. **Update `app_settings` table:**
   - Ensure there's a row with TVA percentage (e.g., 20)
   - Add a column `is_tva_enabled` if not present

## Technical Constraints & Best Practices

1. **Decimal Arithmetic:** NEVER use `double` for monetary values. Always use `Decimal` from `package:decimal/decimal.dart`.

2. **Existing Patterns:** Follow the existing codebase patterns:
   - Hand-written models (no code generation)
   - `StatelessWidget` + `BlocConsumer` for feature UI state
   - `RepositoryProvider` for data access (repositories in `lib/repositories/`)
   - `BlocProvider` for feature state management (cubits in `lib/cubits/`)
   - `Provider` only for cross-widget state (`ThemeProvider`, `LocaleProvider`)
   - Arabic/French/English localization using existing `l10n/` structure

3. **Error Handling:** Use try-catch blocks with user-friendly Arabic/French error messages.

4. **Validation:**
   - HT/TTC amounts must be > 0
   - Bank account must be selected before saving
   - TVA rate must be between 0 and 100

5. **Offline Support:** The app uses Hive for offline caching. Ensure bank account data is cached locally.

6. **Security:** Bank account creation/editing must be admin-only. Use the existing `RoleGuard` widget.

## Deliverables

Please implement ALL of the above in the following order:

1. Database migration SQL files
2. Updated Dart models
3. `CalculationEngine` service
4. Updated `InvoiceRepository` with new methods
5. Bank account management screens
6. Updated invoice form with HT/TTC toggle and bank account selection
7. Updated client form with default bank account
8. PDF service updates
9. `InvoiceCubit` for invoice state management
10. Migration script to backfill existing data

## Testing Requirements

After implementation, verify:
1. Creating an invoice with HT mode calculates TTC correctly
2. Creating an invoice with TTC mode calculates HT correctly
3. Switching between HT/TTC modes updates all fields in real-time
4. Client's default bank account is auto-selected on invoice creation
5. Secretary can override the bank account
6. PDF shows correct currency and amounts
7. TVA rate changes in app_settings are reflected in new invoices
8. No floating-point precision errors (use Decimal throughout)

## Notes

- The `app_settings` table currently has a `percentage` column used for TVA. This will be your source of truth for TVA rates.
- The existing `computeInvoiceTotals` method in `InvoiceRepository` currently uses `double`. You must update it to use `Decimal`.
- The existing `invoices_screen.dart` must continue to work without breaking changes.
- All new UI strings must be added to the localization files (`l10n/tr_*.dart`).
