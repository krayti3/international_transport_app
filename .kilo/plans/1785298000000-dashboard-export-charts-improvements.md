# Implementation Plan: Dashboard Export, Charts, and UI Improvements

## Overview
Apply FINAL_RECOMMENDATIONS.md logic to multiple screens: add PDF/Excel export buttons, make charts responsive, and implement Secretary/Driver interface improvements.

## Files to Modify

### 1. lib/services/pdf_service.dart
- Add `buildDashboardPdf()` method for exporting dashboard financial data as PDF
- Add `buildTripsReportPdf()` method for exporting trip data as PDF
- Add `shareDashboardPdf()` and `previewDashboardPdf()` methods
- Add `buildDriversReportPdf()`, `buildTrucksReportPdf()`, `buildTrailersReportPdf()` methods for list export

### 2. lib/screens/advanced_dashboard_screen.dart
- Add PDF export button in AppBar actions (next to existing Excel button)
- Make chart heights responsive using LayoutBuilder/MediaQuery for big screens
- Increase bar chart heights from 200→300 (monthly) and 150→250 (trips) on large screens

### 3. lib/screens/company_profit_report_screen.dart
- Add PDF export button in AppBar actions (next to existing Excel button)
- Use PdfService to build and share/preview PDF of the profit report

### 4. lib/screens/drivers_screen.dart
- Add PDF export button in AppBar (exports driver list)
- Add Excel export button in AppBar (exports driver list)
- Apply same responsive pattern as owner_dashboard_screen.dart

### 5. lib/screens/trucks_screen.dart
- Add PDF export button in AppBar (exports truck list)
- Add Excel export button in AppBar (exports truck list)
- Apply same responsive pattern

### 6. lib/screens/trailers_screen.dart
- Add PDF export button in AppBar (exports trailer list)
- Add Excel export button in AppBar (exports trailer list)
- Apply same responsive pattern

### 7. lib/screens/secretary_dashboard_screen.dart
- Add Quick Actions bar at top with 3 buttons: "تسليم عهدة جديدة", "إنشاء فاتورة جديدة", "تسوية رحلة معلقة"
- Add Ctrl+N keyboard shortcut for new trip order (web)
- Add overdue invoice alert banner (red) at top if overdue invoices exist
- Add pending trip orders queue section
- Add keyboard shortcuts: Ctrl+N (new trip), Ctrl+I (new invoice), Ctrl+S (save)

### 8. lib/screens/driver_screen.dart
- Hide all financial information (prices, currencies, invoices)
- Add prominent "الرحلة الحالية" card at top with "انطلقت" and "وصلت" buttons
- Add "الرحلات القادمة" list below the card
- Add local notifications for: new trip assignment, departure time change, status change
- Add offline mode with Hive local storage
- Add isSynced field to trip_order model

### 9. lib/models/trip_order.dart
- Add `isSynced` field (bool, default true)
- Update fromMap/toMap/copyWith

### 10. lib/repositories/trip_repository.dart
- Add `updateTripStatusOffline()` method

### 11. lib/services/notification_service.dart
- Add `notifyTripAssigned()` method
- Add `notifyDepartureTimeChanged()` method
- Add `notifyTripStatusChanged()` method

## Verification
- Run `flutter analyze` to check for errors
- Run `flutter test` to verify no regressions
- Test PDF export on each screen
- Test Excel export on each screen
- Test keyboard shortcuts on web/desktop
- Test responsive chart sizing on different screen sizes
