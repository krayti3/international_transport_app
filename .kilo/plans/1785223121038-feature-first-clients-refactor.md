# Feature-First Refactor: Clients Feature

## Goal
Refactor the Clients feature from the monolithic `SupabaseService` into a clean Feature-First architecture with dedicated Repository and Screens folders.

---

## 1. New Folder Structure

```
lib/features/clients/
├── repositories/
│   └── client_repository.dart
└── screens/
    ├── clients_screen.dart
    └── customer_detail_screen.dart
```

---

## 2. Create `lib/features/clients/repositories/client_repository.dart`

This file receives **all client-related methods** moved from `lib/services/supabase_service.dart`.

### Key contents to port:
- `getClients({bool activeOnly = false})`
- `addClient(Client client)`
- `updateClient(Client client, {Map<String, dynamic>? localRow})`
- `deleteClient(int id)`
- `getClientById(String id)`
- `updateClientDefaultBankAccount(int clientId, String bankAccountId)`
- `getTripOrdersByClient(int clientId)`
- `getInvoicePaymentsForClient(int clientId)`
- `getOutstandingInvoices(int clientId)`
- `getClientStatement(int clientId)`
- `isClientInUse(int clientId)`

### Private helpers to also port:
- `_writeClient(...)` - keeps `name`/`company_name` in sync
- `_writeRow(...)` - schema-drift-tolerant writer
- `_updateWithLww(...)` - last-write-wins guard
- `_cacheRows(...)` / `_cacheSingleRow(...)`
- `_normalizeClient(...)`
- `_missingColumnFrom(...)` / `_notNullColumnFrom(...)`

### Constructor signature:
```dart
class ClientRepository {
  final SupabaseClient supabase;
  ClientRepository(this.supabase);
}
```

---

## 3. Move `clients_screen.dart`

**From:** `lib/screens/clients_screen.dart`  
**To:** `lib/features/clients/screens/clients_screen.dart`

### Import changes:
- Remove: `import '../services/supabase_service.dart';`
- Add: `import '../repositories/client_repository.dart';`
- Add: `import 'package:supabase_flutter/supabase_flutter.dart';`

### Instantiation change:
```dart
// Before
final SupabaseService _supabaseService = SupabaseService();

// After
final ClientRepository _clientRepository = ClientRepository(Supabase.instance.client);
```

### Method call changes (client operations only):
- `_supabaseService.getClients()` → `_clientRepository.getClients()`
- `_supabaseService.addClient(...)` → `_clientRepository.addClient(...)`
- `_supabaseService.updateClient(...)` → `_clientRepository.updateClient(...)`

### Non-client operations (keep using SupabaseService for now):
- `getInvoices()` → still from `SupabaseService()` (will move to InvoiceRepository later)
- `getSystemSettings()` → still from `SupabaseService()` (will move to SettingsRepository later)

---

## 4. Move `customer_detail_screen.dart`

**From:** `lib/screens/customer_detail_screen.dart`  
**To:** `lib/features/clients/screens/customer_detail_screen.dart`

### Import changes:
- Remove: `import '../services/supabase_service.dart';`
- Add: `import '../../repositories/client_repository.dart';`

### Instantiation change:
```dart
// Before
final SupabaseService _supabaseService = SupabaseService();

// After
final ClientRepository _clientRepository = ClientRepository(Supabase.instance.client);
```

### Method call changes (client operations only):
- Any future client-specific calls go to `_clientRepository`

### Non-client operations (keep for now):
- `getInvoices()` → `SupabaseService()`
- `getBankAccounts()` → `SupabaseService()`
- `getCashBoxes()` → `SupabaseService()`

---

## 5. Update old file locations (if any other files import the old paths)

Search for any imports pointing to the old screen locations and update them:

```bash
grep -r "screens/clients_screen.dart" lib/
grep -r "screens/customer_detail_screen.dart" lib/
```

Update those imports to point to:
- `features/clients/screens/clients_screen.dart`
- `features/clients/screens/customer_detail_screen.dart`

---

## 6. Validation Checklist

- [ ] `client_repository.dart` compiles without errors
- [ ] `clients_screen.dart` compiles and runs in the new location
- [ ] `customer_detail_screen.dart` compiles and runs in the new location
- [ ] All client CRUD operations work (add, edit, delete, view)
- [ ] Invoice stats and filtering still work on clients screen
- [ ] Customer detail screen loads invoices and bank accounts correctly
- [ ] No remaining imports of `SupabaseService` in the two moved screens for client operations

---

## 7. Future Improvements (Out of Scope for This Plan)

- Create `InvoiceRepository` and move `getInvoices()` there
- Create `SettingsRepository` and move `getSystemSettings()` there
- Create `BankAccountRepository` for bank account operations
- Add DI layer (GetIt/Provider) to inject repositories instead of manual instantiation
- Extract `_writeRow` and `_updateWithLww` into a shared `DatabaseHelper` or `BaseRepository`

---

## Implementation Order

1. Create `lib/features/clients/repositories/client_repository.dart`
2. Create `lib/features/clients/screens/` directory
3. Create new `clients_screen.dart` in the new location with updated imports
4. Create new `customer_detail_screen.dart` in the new location with updated imports
5. Delete old `lib/screens/clients_screen.dart` and `lib/screens/customer_detail_screen.dart`
6. Update any other files that imported the old screen paths
7. Run `flutter analyze` and fix any remaining import issues
