import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/aging_report_screen.dart';
import 'screens/bank_accounts_screen.dart';
import 'screens/cash_box_ledger_screen.dart';
import 'screens/cash_box_management_screen.dart';
import 'screens/client_statement_screen.dart';
import 'screens/client_reports_screen.dart';
import 'features/clients/screens/clients_screen.dart';
import 'screens/company_profit_report_screen.dart';
import 'screens/current_trips_screen.dart';
import 'screens/debt_invoice_form_screen.dart';
import 'screens/document_categories_screen.dart';
import 'screens/driver_advances_screen.dart';
import 'screens/driver_cash_screen.dart';
import 'screens/driver_salary_screen.dart';
import 'screens/driver_tasks_screen.dart';
import 'screens/drivers_screen.dart';
import 'screens/expense_categories_screen.dart';
import 'screens/expense_workshop_report_screen.dart';
import 'screens/fleet_docs_screen.dart';
import 'screens/fuel_receipt_screen.dart';
import 'screens/invoice_form_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/international_trip_screen.dart';
import 'screens/location_picker_screen.dart';
import 'screens/maintenance_schedule_screen.dart';
import 'screens/oil_change_alerts_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/outstanding_invoices_screen.dart';
import 'screens/overdue_reminders_screen.dart';
import 'screens/providers_screen.dart';
import 'screens/repair_invoice_form_screen.dart';
import 'screens/secretary_dashboard_screen.dart';
import 'screens/secretary_ledger_screen.dart';
import 'screens/system_settings_screen.dart';
import 'screens/trailer_maintenance_screen.dart';
import 'screens/trailers_screen.dart';
import 'screens/treasury_management_screen.dart';
import 'screens/treasury_screen.dart';
import 'screens/trip_form_screen.dart';
import 'screens/trip_orders_screen.dart';
import 'screens/truck_documents_screen.dart';
import 'screens/truck_tracking_screen.dart';
import 'screens/trucks_screen.dart';
import 'screens/vehicle_doc_type_screen.dart';
import 'screens/visa_tracking_screen.dart';
import 'screens/workshop_payment_preview_screen.dart';
import 'screens/workshop_repairs_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/signup_screen.dart';

class AppRoute {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const adminDashboard = '/admin-dashboard';
  static const ownerDashboard = '/owner-dashboard';
  static const secretaryDashboard = '/secretary-dashboard';
  static const treasury = '/treasury';
  static const treasuryManagement = '/treasury-management';
  static const cashBoxManagement = '/cash-box-management';
  static const cashBoxLedger = '/cash-box-ledger';
  static const truckTracking = '/truck-tracking';
  static const tripOrders = '/trip-orders';
  static const currentTrips = '/current-trips';
  static const internationalTrip = '/international-trip';
  static const tripForm = '/trip-form';
  static const invoices = '/invoices';
  static const outstandingInvoices = '/outstanding-invoices';
  static const overdueReminders = '/overdue-reminders';
  static const agingReport = '/aging-report';
  static const clientReports = '/client-reports';
  static const clients = '/clients';
  static const clientStatement = '/client-statement';
  static const secretaryLedger = '/secretary-ledger';
  static const drivers = '/drivers';
  static const driverSalary = '/driver-salary';
  static const driverCash = '/driver-cash';
  static const driverAdvances = '/driver-advances';
  static const driverTasks = '/driver-tasks';
  static const trucks = '/trucks';
  static const truckDocuments = '/truck-documents';
  static const trailers = '/trailers';
  static const fleetDocs = '/fleet-docs';
  static const trailerMaintenance = '/trailer-maintenance';
  static const maintenanceSchedule = '/maintenance-schedule';
  static const fuelReceipt = '/fuel-receipt';
  static const providers = '/providers';
  static const workshopRepairs = '/workshop-repairs';
  static const repairInvoiceForm = '/repair-invoice-form';
  static const workshopPaymentPreview = '/workshop-payment-preview';
  static const expenseWorkshopReport = '/expense-workshop-report';
  static const expenseCategories = '/expense-categories';
  static const documentCategories = '/document-categories';
  static const vehicleDocType = '/vehicle-doc-type';
  static const oilChangeAlerts = '/oil-change-alerts';
  static const systemSettings = '/system-settings';
  static const companyProfitReport = '/company-profit-report';
  static const bankAccounts = '/bank-accounts';
  static const visaTracking = '/visa-tracking';
  static const locationPicker = '/location-picker';
  static const invoiceForm = '/invoice-form';
  static const debtInvoiceForm = '/debt-invoice-form';
}

enum AppRole { admin, secretary, driver }

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

class _RoleCache {
  static String? _role;
  static DateTime? _fetchedAt;

  static Future<String?> getRole() async {
    if (_role != null && _fetchedAt != null) {
      final age = DateTime.now().difference(_fetchedAt!);
      if (age.inMinutes < 10) return _role;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _role = null;
      _fetchedAt = null;
      return null;
    }
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      _role = response?['role']?.toString();
      _fetchedAt = DateTime.now();
      return _role;
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      return null;
    }
  }

  static String? getCachedRole() {
    if (_role != null && _fetchedAt != null) {
      final age = DateTime.now().difference(_fetchedAt!);
      if (age.inMinutes < 10) return _role;
    }
    return null;
  }
}

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    refreshListenable: _AuthStateNotifier(),
    initialLocation: AppRoute.login,
    redirect: _redirect,
    errorBuilder: _errorBuilder,
    routes: _routes,
  );

  static String? _redirect(BuildContext context, GoRouterState state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == AppRoute.login ||
        state.matchedLocation == AppRoute.signup;

    if (!isLoggedIn && !isAuthRoute) {
      return AppRoute.login;
    }
    if (isLoggedIn && isAuthRoute) {
      return AppRoute.home;
    }
    return null;
  }

  static Widget _errorBuilder(BuildContext context, GoRouterState state) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ غير متوقع',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoute.home),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _roleGuard({
    required BuildContext context,
    required List<String> allowedRoles,
    required Widget child,
  }) {
    return FutureBuilder<String?>(
      future: _RoleCache.getRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = snapshot.data;
        if (role == null || !allowedRoles.contains(role)) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 64, color: Colors.red),
                  const SizedBox(height: 24),
                  Text(
                    'ليس لديك صلاحية للوصول إلى هذا القسم',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('رجوع'),
                  ),
                ],
              ),
            ),
          );
        }
        return child;
      },
    );
  }

  static GoRoute _protectedRoute({
    required String name,
    required String path,
    required Widget Function(BuildContext, GoRouterState) builder,
    required List<String> allowedRoles,
  }) {
    return GoRoute(
      name: name,
      path: path,
      builder: (context, state) {
        return _roleGuard(
          context: context,
          allowedRoles: allowedRoles,
          child: builder(context, state),
        );
      },
    );
  }

  static bool _isAdmin(String? role) => role == 'admin';

  static GoRoute _adminRoute({
    required String name,
    required String path,
    required Widget Function(BuildContext, GoRouterState) builder,
  }) {
    return _protectedRoute(
      name: name,
      path: path,
      builder: builder,
      allowedRoles: ['admin'],
    );
  }

  static GoRoute _adminSecretaryRoute({
    required String name,
    required String path,
    required Widget Function(BuildContext, GoRouterState) builder,
  }) {
    return _protectedRoute(
      name: name,
      path: path,
      builder: builder,
      allowedRoles: ['admin', 'secretary'],
    );
  }

  static GoRoute _allRolesRoute({
    required String name,
    required String path,
    required Widget Function(BuildContext, GoRouterState) builder,
  }) {
    return _protectedRoute(
      name: name,
      path: path,
      builder: builder,
      allowedRoles: ['admin', 'secretary', 'driver'],
    );
  }

  static final List<GoRoute> _routes = [
    GoRoute(
      name: AppRoute.login,
      path: AppRoute.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      name: AppRoute.signup,
      path: AppRoute.signup,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      name: AppRoute.home,
      path: AppRoute.home,
      builder: (context, state) => const MainScreen(),
    ),
    _adminRoute(
      name: AppRoute.adminDashboard,
      path: AppRoute.adminDashboard,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    _adminRoute(
      name: AppRoute.ownerDashboard,
      path: AppRoute.ownerDashboard,
      builder: (context, state) => const OwnerDashboardScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.secretaryDashboard,
      path: AppRoute.secretaryDashboard,
      builder: (context, state) => const SecretaryDashboardScreen(),
    ),
    _allRolesRoute(
      name: AppRoute.treasury,
      path: AppRoute.treasury,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return TreasuryScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminRoute(
      name: AppRoute.treasuryManagement,
      path: AppRoute.treasuryManagement,
      builder: (context, state) => const TreasuryManagementScreen(),
    ),
    _adminRoute(
      name: AppRoute.cashBoxManagement,
      path: AppRoute.cashBoxManagement,
      builder: (context, state) => const CashBoxManagementScreen(),
    ),
    _allRolesRoute(
      name: AppRoute.cashBoxLedger,
      path: AppRoute.cashBoxLedger,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return CashBoxLedgerScreen(isAdmin: _isAdmin(r));
      },
    ),
    _allRolesRoute(
      name: AppRoute.truckTracking,
      path: AppRoute.truckTracking,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return TruckTrackingScreen(isAdmin: _isAdmin(r));
      },
    ),
    _allRolesRoute(
      name: AppRoute.tripOrders,
      path: AppRoute.tripOrders,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return TripOrdersScreen(isAdmin: _isAdmin(r));
      },
    ),
    _allRolesRoute(
      name: AppRoute.currentTrips,
      path: AppRoute.currentTrips,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return CurrentTripsScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminRoute(
      name: AppRoute.internationalTrip,
      path: AppRoute.internationalTrip,
      builder: (context, state) => const InternationalTripScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.tripForm,
      path: AppRoute.tripForm,
      builder: (context, state) => const TripFormScreen(),
    ),
    _allRolesRoute(
      name: AppRoute.invoices,
      path: AppRoute.invoices,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return InvoicesScreen(isAdmin: _isAdmin(r));
      },
    ),
    _allRolesRoute(
      name: AppRoute.outstandingInvoices,
      path: AppRoute.outstandingInvoices,
      builder: (context, state) => const OutstandingInvoicesScreen(),
    ),
    _allRolesRoute(
      name: AppRoute.overdueReminders,
      path: AppRoute.overdueReminders,
      builder: (context, state) => const OverdueRemindersScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.agingReport,
      path: AppRoute.agingReport,
      builder: (context, state) => const AgingReportScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.clientReports,
      path: AppRoute.clientReports,
      builder: (context, state) => const ClientReportsScreen(),
    ),
    _allRolesRoute(
      name: AppRoute.clients,
      path: AppRoute.clients,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return ClientsScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.clientStatement,
      path: AppRoute.clientStatement,
      builder: (context, state) => const ClientStatementScreen(
        clientId: 0,
        clientName: '',
      ),
    ),
    _adminSecretaryRoute(
      name: AppRoute.secretaryLedger,
      path: AppRoute.secretaryLedger,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return SecretaryLedgerScreen(
          userRole: r ?? 'secretary',
        );
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.drivers,
      path: AppRoute.drivers,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return DriversScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.driverSalary,
      path: AppRoute.driverSalary,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return DriverSalaryScreen(isAdmin: _isAdmin(r));
      },
    ),
    _allRolesRoute(
      name: AppRoute.driverCash,
      path: AppRoute.driverCash,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        final uid = Supabase.instance.client.auth.currentUser?.id;
        return DriverCashScreen(
          driverId: uid != null ? int.tryParse(uid) ?? 0 : 0,
          driverName: r == 'driver' ? 'السائق' : 'السائق',
        );
      },
    ),
    _allRolesRoute(
      name: AppRoute.driverAdvances,
      path: AppRoute.driverAdvances,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        final uid = Supabase.instance.client.auth.currentUser?.id;
        return DriverAdvancesScreen(
          isAdmin: _isAdmin(r),
          driverId: uid != null ? int.tryParse(uid) ?? 0 : 0,
        );
      },
    ),
    _allRolesRoute(
      name: AppRoute.driverTasks,
      path: AppRoute.driverTasks,
      builder: (context, state) => const DriverTasksScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.trucks,
      path: AppRoute.trucks,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return TrucksScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.truckDocuments,
      path: AppRoute.truckDocuments,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return TruckDocumentsScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.trailers,
      path: AppRoute.trailers,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return TrailersScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.fleetDocs,
      path: AppRoute.fleetDocs,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return FleetDocsScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.trailerMaintenance,
      path: AppRoute.trailerMaintenance,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return TrailerMaintenanceScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.maintenanceSchedule,
      path: AppRoute.maintenanceSchedule,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return MaintenanceScheduleScreen(isAdmin: _isAdmin(r));
      },
    ),
    _allRolesRoute(
      name: AppRoute.fuelReceipt,
      path: AppRoute.fuelReceipt,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return FuelReceiptScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.providers,
      path: AppRoute.providers,
      builder: (context, state) => const ProvidersScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.workshopRepairs,
      path: AppRoute.workshopRepairs,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return WorkshopRepairInvoicesScreen(
          workshopId: '',
          workshopName: 'جميع الورش',
          isAdmin: _isAdmin(r),
        );
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.repairInvoiceForm,
      path: AppRoute.repairInvoiceForm,
      builder: (context, state) {
        return RepairInvoiceFormScreen(
          workshopId: '',
          workshopName: '',
        );
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.workshopPaymentPreview,
      path: AppRoute.workshopPaymentPreview,
      builder: (context, state) {
        return WorkshopPaymentPreviewScreen(
          workshopName: '',
          invoices: [],
          paymentAmount: 0,
          method: '',
          ref: '',
        );
      },
    ),
    _adminSecretaryRoute(
      name: AppRoute.expenseWorkshopReport,
      path: AppRoute.expenseWorkshopReport,
      builder: (context, state) => const ExpenseWorkshopReportScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.expenseCategories,
      path: AppRoute.expenseCategories,
      builder: (context, state) => const ExpenseCategoriesScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.documentCategories,
      path: AppRoute.documentCategories,
      builder: (context, state) => const DocumentCategoriesScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.vehicleDocType,
      path: AppRoute.vehicleDocType,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return VehicleDocTypeScreen(
          isAdmin: _isAdmin(r),
          entityType: 'truck',
          entityId: 0,
          docType: '',
        );
      },
    ),
    _adminRoute(
      name: AppRoute.oilChangeAlerts,
      path: AppRoute.oilChangeAlerts,
      builder: (context, state) {
        final r = _RoleCache.getCachedRole();
        return OilChangeAlertsScreen(isAdmin: _isAdmin(r));
      },
    ),
    _adminRoute(
      name: AppRoute.systemSettings,
      path: AppRoute.systemSettings,
      builder: (context, state) => const SystemSettingsScreen(),
    ),
    _adminRoute(
      name: AppRoute.companyProfitReport,
      path: AppRoute.companyProfitReport,
      builder: (context, state) => const CompanyProfitReportScreen(),
    ),
    _adminRoute(
      name: AppRoute.bankAccounts,
      path: AppRoute.bankAccounts,
      builder: (context, state) => const BankAccountsScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.visaTracking,
      path: AppRoute.visaTracking,
      builder: (context, state) => const VisaTrackingScreen(),
    ),
    _allRolesRoute(
      name: AppRoute.locationPicker,
      path: AppRoute.locationPicker,
      builder: (context, state) => const LocationPickerScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.invoiceForm,
      path: AppRoute.invoiceForm,
      builder: (context, state) => const InvoiceFormScreen(),
    ),
    _adminSecretaryRoute(
      name: AppRoute.debtInvoiceForm,
      path: AppRoute.debtInvoiceForm,
      builder: (context, state) => const DebtInvoiceFormScreen(),
    ),
  ];
}