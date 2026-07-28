# Advanced Dashboard & Reports - Implementation Plan

## Overview
Add a comprehensive financial dashboard screen that combines trip profits, truck expenses (independent of secretary authority), and invoice status (paid/unpaid/partially paid) in both MAD and EUR currencies.

## Files to Create

### 1. `lib/cubits/advanced_dashboard_cubit.dart` + `lib/cubits/advanced_dashboard_state.dart`
- `AdvancedDashboardCubit` fetches and aggregates:
  - Trip orders with revenue (price - specificExpenses)
  - Truck maintenance expenses from `truck_maintenance` table
  - Treasury transactions (trip_expense, office_expense, salary, etc.)
  - Invoices grouped by status and currency (MAD/EUR)
- State holds: `isLoading`, `errorMessage`, `totalRevenue`, `totalExpenses`, `netProfit`, `invoicesByStatus`, `expensesByCategory`, `tripsByMonth`

### 2. `lib/screens/advanced_dashboard_screen.dart`
- StatelessWidget using BlocConsumer
- Top section: Summary cards (Total Revenue, Total Expenses, Net Profit, Outstanding Invoices)
- Middle section: Charts (bar chart for monthly revenue vs expenses, pie chart for expense breakdown)
- Bottom section: Invoice status table with MAD/EUR columns
- Date range selector (this month, last month, custom range)
- Export to PDF and Excel buttons

### 3. Update `lib/screens/home_screen.dart`
- Add import for `advanced_dashboard_screen.dart`
- Add navigation item under "لوحة التحكم والتحليلات" section

### 4. Update `lib/screens/main_dashboard_template.dart`
- Add navigation entry for Advanced Dashboard

## Key Design Decisions
- Use existing `Repository` classes where possible (e.g., `TreasuryRepository`, `TripRepository`)
- Add new `getAdvancedDashboardReport()` method to the appropriate repository for aggregated data
- Follow the existing cubit pattern (BlocConsumer, StatelessWidget)
- Use `flutter_charts` or custom Flutter charts (no new dependencies if possible)
- Arabic UI text preserved throughout
- Admin-only access (same as admin_dashboard_screen.dart)

## Verification
- Run `flutter analyze` to check for errors
- Run `flutter build web` to verify compilation
- Test navigation from home screen to dashboard
