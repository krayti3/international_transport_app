# International Transport App — AI Understanding Package

## 🎯 Purpose

This package contains all essential files to help an external AI (or any developer) understand how this Flutter application works, its architecture, business logic, and database schema.

---

## 📦 Package Contents

This package (`ai_understanding_package.zip`) includes:

### 1. Core Application Files
- `lib/main.dart` — App entry point, Hive/Supabase/Bloc initialization
- `lib/app_router.dart` — go_router routing with role-based guards
- `lib/screens/home_screen.dart` — Main home screen with 3-level sidebar

### 2. State Management (Cubits)
- `lib/cubits/*.dart` — 22 files (treasury, invoices, drivers, trucks, trailers, trips, chat, AI reports, etc.)

### 3. Data Layer (Repositories)
- `lib/repositories/*.dart` — 14 files (Supabase API abstraction layer)

### 4. Data Models
- `lib/models/*.dart` — 24 Dart models (client, invoice, trip, truck, driver, etc.)

### 5. Services
- `lib/services/*.dart` — 14 service files (PDF, Excel, ML Kit, Map, Notifications, Cache, Sync)

### 6. Documentation
- `README.md` — Project overview, tech stack, database schema, business logic
- `current_status.md` — Current implementation status (in Arabic)
- `screen_index.md` — Index of all 67 screens
- `supabase/migrations_run_me.sql` — **COMPLETE DATABASE SCHEMA** (single file with all migrations)
- `USER_GUIDE_SECRETARY.md` — Secretary user guide (in Arabic)

---

## 🏗️ How the Application Works

### Architecture Pattern
The app follows a **clean architecture** with separate layers:
1. **UI Layer** — Screens (StatelessWidget + BlocConsumer)
2. **State Layer** — Cubits + States (flutter_bloc)
3. **Data Layer** — Repositories + Models
4. **Service Layer** — PDF, Excel, ML, Map, Notifications
5. **Database** — Supabase PostgreSQL

### State Management
- Uses **Cubit pattern** (from flutter_bloc)
- Each feature has its own Cubit + State pair
- UI rebuilds via `BlocConsumer` or `BlocBuilder`
- Only Theme/Locale use Provider (not features)

### Navigation
- **go_router** for declarative routing
- `RoleGuard` widget protects routes by role (admin/secretary/driver)

### Data Flow
```
Screen → Cubit → Repository → Supabase REST API → PostgreSQL
                    ↓
              Local Cache (Hive)
```

### Offline Support
- Hive stores entities locally with 15-minute TTL
- Cache-then-Network pattern (show cache first, refresh in background)

---

## 🔐 Three User Roles

| Role | Access |
|------|--------|
| **Admin** | Full access + financial reports + TVA settings + user management |
| **Secretary** | Daily operations (trips, invoices, cash, clients) — delete disabled |
| **Driver** | Dedicated screen showing only assigned trips |

---

## 🗄️ Database Schema

### Main Tables
| Table | Purpose |
|-------|---------|
| `users` | RBAC users (id, email, role) |
| `clients` | Customers & companies |
| `trucks` | Fleet trucks (with GPS, odometer, default_trailer) |
| `trailers` | Trailers |
| `drivers` | Drivers (with salary, bonus, default_truck) |
| `advances` | Trip advances / missions (status: pending→en_route→settled) |
| `trip_orders` | Trip legs (outbound/return) |
| `invoices` | Invoices (with bank_account, HT/TTC mode, currency) |
| `payments` + `payment_invoice_allocations` | FIFO payment distribution |
| `treasury_transactions` | Cash flow (6 types: capital, revenue, withdrawal, expense, salary, trip_expense) |
| `app_settings` | TVA rate + toggle |
| `bank_accounts` | Multi-currency accounts (MAD/EUR) |
| `truck_maintenance` | Truck maintenance records |
| `trailer_maintenance` | Trailer maintenance records |
| `driver_salaries` | Driver salaries + bonuses |
| `notifications` | Realtime notifications |
| `chat_messages` | Internal chat with images |
| `repair_invoices` + `workshop_payments` | Workshop repair invoices |

### Key Relationships
```
client 1---* invoice *---1 bank_account
driver 1---* advance
truck 1---* advance
trailer 1---* advance
advance 1---* trip_order
driver 1---* driver_salary
truck 1---* truck_maintenance
```

### Business Logic
1. **FIFO Payments**: When a client pays, system auto-distributes to oldest unpaid invoices first
2. **HT/TTC**: Invoices in HT or TTC mode with automatic TVA calculation
3. **Multi-currency**: Each invoice linked to a bank account (MAD or EUR)
4. **Realtime**: Changes sync via Supabase Realtime subscriptions

---

## 🔄 Core Business Workflows

### 1. International Trip Creation
```
1. Secretary selects client + driver + truck + trailer
2. Enters route (outbound/return), dates, price, currency
3. System creates `advances` row + `trip_orders` rows
4. Realtime notification sent to driver
```

### 2. Cash Advance Delivery
```
1. Secretary opens "تسليم عهدة جديدة"
2. Selects driver + amount + date
3. Creates `advances` row (status: en_route)
4. Records `treasury_transactions` (trip_expense)
```

### 3. Trip Settlement
```
1. Secretary selects pending advance
2. Enters actual expenses (fuel, road, others)
3. System calculates net amount
4. Updates advance → status: settled
5. Creates treasury_transactions entries
6. Triggers driver salary calculation
```

### 4. Invoice Creation
```
1. Secretary selects client
2. Auto-selects client's default bank account (MAD/EUR)
3. Chooses HT/TTC mode
4. Enters amount → system calculates HT/TVA/TTC
5. Creates invoice with selected currency
```

### 5. Payment Collection (FIFO)
```
1. Secretary registers payment from client
2. System fetches unpaid invoices ordered by date ASC
3. Allocates payment starting from oldest invoice
4. Updates invoice status: unpaid → partially_paid → paid
5. Records allocation in payment_invoice_allocations
```

### 6. Fuel Receipt AI Scanning
```
1. User captures photo of fuel receipt
2. ML Kit Text Recognition extracts text
3. System parses: station, quantity, amount, date
4. Auto-fills form → saves as trip expense
```

### 7. Truck GPS Tracking
```
1. Driver app sends GPS coordinates
2. Updates truck's current_latitude/longitude
3. Secretary/Admin views real-time map
4. flutter_map displays truck location
```

---

## 📱 Screens (67 Total)

### Secretary Views (operational)
- `home_screen.dart` — Main dashboard with sidebar
- `advances_screen.dart` — Trip advances
- `trip_form_screen.dart` — New trip / settlement
- `invoices_screen.dart` — Invoice management
- `clients_screen.dart` — Client management
- `trucks_screen.dart` — Truck management
- `trailers_screen.dart` — Trailer management
- `drivers_screen.dart` — Driver management
- `treasury_screen.dart` / `treasury_management_screen.dart` — Treasury
- `truck_maintenance_screen.dart` — Truck maintenance
- `driver_salary_screen.dart` — Driver salaries
- `chat_screen.dart` — Internal chat
- `reports` (aging, overdue, client statements, profit reports)
- `oil_change_alerts_screen.dart` — Oil change alerts
- `fuel_receipt_screen.dart` — AI fuel receipt scanner

### Admin Views (management)
- `admin_dashboard_screen.dart` — Admin analytics
- `advanced_dashboard_screen.dart` — Advanced analytics
- `bank_accounts_screen.dart` — Bank account management
- `system_settings_screen.dart` — TVA and app settings
- `providers_screen.dart` — Provider management
- `ai_reports_screen.dart` — AI-powered reports

### Driver Views (mobile)
- `driver_screen.dart` — Driver's main screen
- `driver_trips_screen.dart` — Assigned trips
- `driver_advances_screen.dart` — Advance history
- `driver_tasks_screen.dart` — Tasks
- `driver_cash_screen.dart` — Cash operations

---

## 🛠️ Technical Constraints

1. **No floating-point for money** — All calculations use `Decimal` type
2. **Date format** — Always `dd/mm/yyyy` with `Locale('ar', 'MA')`
3. **Arabic-first UI** — RTL layout, Arabic/French/English support
4. **Offline-first** — Hive cache with 15-minute TTL
5. **Single Supabase project** — All data in one PostgreSQL database
6. **No ORM** — Hand-written models with `fromMap`/`toMap`/`copyWith`
7. **PWA ready** — Flutter web with service worker

---

## 🚀 How to Deploy

1. **Supabase Setup**:
   - Create project on supabase.com
   - Run `supabase/migrations_run_me.sql` in SQL Editor
   - Get URL + anon key

2. **Flutter App**:
   - `flutter pub get`
   - Update `.env` with Supabase credentials
   - `flutter run` (mobile) or `flutter run -d chrome` (web)

3. **Web Deployment**:
   - `flutter build web`
   - Deploy `build/web/` to any static host (Nginx, Vercel, etc.)
   - Configure as PWA

---

## 💡 Key Insights for External AI

### If you need to ADD a new feature:
1. **Database**: Add migration in `supabase/migrations/`
2. **Model**: Create in `lib/models/` (hand-written, no codegen)
3. **Repository**: Create in `lib/repositories/` (fetches from Supabase)
4. **Cubit + State**: Create in `lib/cubits/`
5. **Screen**: Create in `lib/screens/` (StatelessWidget + BlocConsumer)
6. **Register in main.dart**: Add providers, cubits, repositories
7. **Add route in app_router.dart**: With RoleGuard if needed
8. **Localization**: Add strings in `lib/l10n/`

### If you need to MODIFY existing feature:
1. Find the Cubit → Repository → Model chain
2. Modify migration if DB schema changes
3. Update model `fromMap`/`toMap`
4. Update repository queries
5. Update Cubit logic if needed
6. Update UI in screen

### Critical Patterns:
- **Cubits hold state & business logic**
- **Repositories handle all DB calls**
- **Screens are dumb** (only UI + user input)
- **All async via emit() → BlocConsumer**
- **Error handling**: try-catch in Cubit, show SnackBar in UI

---

## 📊 Project Stats

| Metric | Value |
|--------|-------|
| Total Screens | 67 |
| Total Models | 24 |
| Total Cubits | 18 (+ states) |
| Total Repositories | 14 |
| Total Services | 14 |
| Total Migrations | 33+ |
| Database Tables | 15+ |
| User Roles | 3 (admin, secretary, driver) |
| Supported Languages | 3 (Arabic, French, English) |
| Lines of Code | ~50,000+ |

---

## ⚠️ Important Notes

1. **Multi-currency billing is partially implemented** — See `KILOCODE_PROMPT_MULTI_CURRENCY_BILLING.md`
2. **Performance plan exists** — See `PERFORMANCE_AND_USABILITY_PLAN.md`
3. **Some sections are placeholders** — Check `current_status.md` for status
4. **Database migrations need to be executed** in Supabase SQL Editor
5. **The app is NOT fully tested** — Run `flutter run` to verify

---

## 🔗 File Relationships

```
main.dart
  ├── AppRouter (go_router)
  ├── MultiRepositoryProvider
  ├── MultiBlocProvider (cubits)
  └── MultiProvider (Theme, Locale)

app_router.dart
  ├── Routes for all screens
  ├── RoleGuard middleware
  └── Redirect logic

home_screen.dart
  ├── 3-level sidebar (accordion)
  ├── Role-based menu items
  └── Navigation to all screens

cubits/
  ├── Hold state
  ├── Call repositories
  ├── Emit new states
  └── Handle errors

repositories/
  ├── Call Supabase REST API
  ├── Map JSON to Models
  └── Handle HTTP errors

models/
  ├── fromMap() — parse JSON
  ├── toMap() — send JSON
  └── copyWith() — immutability

services/
  ├── pdf_service.dart — PDF generation
  ├── excel_service.dart — Excel export
  ├── notification_service.dart — Firebase-like notifications
  ├── ml_text_recognition_service.dart — OCR for fuel receipts
  ├── location_service.dart — GPS tracking
  ├── calculation_engine.dart — Decimal calculations
  └── supabase_service.dart — Legacy monolithic (being replaced by repositories)
```

---

## 📞 Contact

For questions about this project, contact the development team.

**Generated:** 2026-07-28
