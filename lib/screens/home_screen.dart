import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

import '../providers/theme_provider.dart';

import '../widgets/role_guard.dart';
import 'admin_dashboard_screen.dart';
import 'treasury_screen.dart';
import 'fuel_receipt_screen.dart';
import 'truck_tracking_screen.dart';
import 'driver_salary_screen.dart';
import 'owner_dashboard_screen.dart';
import 'company_profit_report_screen.dart';
import 'system_settings_screen.dart';
import 'trip_orders_screen.dart';
import 'current_trips_screen.dart';
import 'international_trip_screen.dart';
import 'trip_form_screen.dart';
import 'invoices_screen.dart';
import 'outstanding_invoices_screen.dart';
import 'overdue_reminders_screen.dart';
import 'aging_report_screen.dart';
import 'client_reports_screen.dart';
import 'treasury_management_screen.dart';
import 'secretary_ledger_screen.dart';
import 'secretary_dashboard_screen.dart';
import 'drivers_screen.dart';
import 'trucks_screen.dart';
import 'trailers_screen.dart';
import 'providers_screen.dart';
import 'expense_workshop_report_screen.dart';
import 'truck_documents_screen.dart';
import 'clients_screen.dart';
import 'driver_tasks_screen.dart';
import 'fleet_docs_screen.dart';
import 'expense_categories_screen.dart';
import 'document_categories_screen.dart';
import 'workshop_repairs_screen.dart';
import 'trailer_maintenance_screen.dart';
import 'driver_cash_screen.dart';
import 'cash_box_management_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  int _currentTabIndex = 0;
  String _userRole = 'Driver';
  String _userEmail = '';
  String? _logoUrl;
  Set<String> _expandedSections = {};

  bool _isLoadingAdvances = true;
  double _totalAdvancesGiven = 0.0;
  double _totalExpensesReturned = 0.0;
  double _remainingBalance = 0.0;

  int _expiringVisasCount = 0;
  List<Map<String, dynamic>> _expiringVisas = [];
  List<Map<String, dynamic>> _expiringFleetDocs = [];
  List<Map<String, dynamic>> _expiringTruckDocs = [];
  List<Map<String, dynamic>> _expiringTrailerDocs = [];
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _trailers = [];

  @override
  void initState() {
    super.initState();
    _fetchUserSessionAndRole();
    _loadExpiringVisasCount();
    _loadExpiringFleetDocsCount();
    _loadLogo();
    _expandedSections = {};
  }

  Future<void> _loadLogo() async {
    try {
      final response = await _supabase
          .from('system_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _logoUrl = response?['logo_url']?.toString();
        });
      }
    } catch (e) {
      // Keep default icon on error
    }
  }

  void _fetchUserSessionAndRole() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? '';
      });
      _loadRoleFromDatabase();
    }
  }

  Future<void> _loadRoleFromDatabase() async {
    final rawRole = await SupabaseService().getUserRole();
    if (!mounted) return;
    setState(() {
      switch (rawRole?.toLowerCase()) {
        case 'admin':
          _userRole = 'Admin';
          break;
        case 'secretary':
          _userRole = 'Secretary';
          break;
        case 'driver':
          _userRole = 'Driver';
          break;
        default:
          _userRole = 'Driver';
      }
    });

    if (_userRole != 'Driver') {
      _loadAdvancesSummary();
      _loadExpiringVisasCount();
      _loadExpiringFleetDocsCount();
    }
  }

  Future<void> _loadAdvancesSummary() async {
    if (!mounted) return;
    setState(() {
      _isLoadingAdvances = true;
    });

    try {
      final bool isAdmin = _userRole == 'Admin';
      final advances = isAdmin
          ? await SupabaseService().getAllAdvances()
          : await SupabaseService().getAdvances();

      double totalGiven = 0.0;
      double totalSpent = 0.0;

      for (final advance in advances) {
        totalGiven += (advance['amount_given'] as num?)?.toDouble() ?? 0.0;
        totalSpent += (advance['amount_spent'] as num?)?.toDouble() ?? 0.0;
      }

      if (!mounted) return;
      setState(() {
        _totalAdvancesGiven = totalGiven;
        _totalExpensesReturned = totalSpent;
        _remainingBalance = totalGiven - totalSpent;
        _isLoadingAdvances = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAdvances = false;
      });
    }
  }

  Future<void> _loadExpiringVisasCount() async {
    try {
      final visas = await SupabaseService().getExpiringVisas();
      if (!mounted) return;
      setState(() {
        _expiringVisas = visas;
        _expiringVisasCount = visas.length;
      });
    } catch (e) {
      debugPrint('Error loading expiring visas count: $e');
    }
  }

  Future<void> _loadExpiringFleetDocsCount() async {
    try {
      final trucks = await SupabaseService().getTrucks();
      final trailers = await SupabaseService().getTrailers();
      final docs = await SupabaseService().getExpiringFleetDocs();
      if (!mounted) return;
      setState(() {
        _trucks = trucks;
        _trailers = trailers;
        _expiringFleetDocs = docs;
        _expiringTruckDocs = docs.where((d) => d['entity_type'] == 'truck').toList();
        _expiringTrailerDocs = docs.where((d) => d['entity_type'] == 'trailer').toList();
      });
    } catch (e) {
      debugPrint('Error loading expiring fleet docs: $e');
    }
  }

  void _showAlertDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final totalAlerts = _expiringVisasCount + _expiringFleetDocs.length;
    if (totalAlerts == 0) return;

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 3,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: colorScheme.tertiary),
              const SizedBox(width: 8),
              Text('تنبيهات الانتهاء ($totalAlerts)'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.75,
            height: 400,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'تأشيرات السائقين'),
                    Tab(text: 'وثائق الشاحنات'),
                    Tab(text: 'وثائق المقطورات'),
                  ],
                  labelStyle: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildVisaList(),
                      _buildFleetDocList(_expiringTruckDocs, 'truck'),
                      _buildFleetDocList(_expiringTrailerDocs, 'trailer'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  Widget _buildVisaList() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_expiringVisas.isEmpty) {
      return Center(child: Text('لا توجد تأشيرات منتهية', style: TextStyle(color: colorScheme.onSurfaceVariant)));
    }
    return ListView.builder(
      itemCount: _expiringVisas.length,
      itemBuilder: (context, index) {
        final driver = _expiringVisas[index];
        final expiryStr = driver['visa_expiry_date']?.toString() ?? '';
        final expiryDate = DateTime.tryParse(expiryStr);
        final diff = expiryDate?.difference(DateTime.now()).inDays;
        String status = 'غير معروف';
        if (diff != null) {
          if (diff < 0) {
            status = 'انتهت منذ ${diff.abs()} يوم';
          } else if (diff == 0) {
            status = 'تنتهي اليوم';
          } else {
            status = 'متبقي $diff يوم';
          }
        }
        return ListTile(
          dense: true,
          leading: const Icon(Icons.person_outline_rounded, size: 20),
          title: Text(driver['name']?.toString() ?? 'بدون اسم'),
          subtitle: Text(status),
        );
      },
    );
  }

  Widget _buildFleetDocList(List<Map<String, dynamic>> docs, String entityType) {
    final colorScheme = Theme.of(context).colorScheme;
    if (docs.isEmpty) {
      return Center(child: Text('لا توجد وثائق منتهية', style: TextStyle(color: colorScheme.onSurfaceVariant)));
    }
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final expiryStr = doc['expiry_date']?.toString() ?? '';
        final expiryDate = DateTime.tryParse(expiryStr);
        final diff = expiryDate?.difference(DateTime.now()).inDays;
        String status = 'غير معروف';
        if (diff != null) {
          if (diff < 0) {
            status = 'انتهت منذ ${diff.abs()} يوم';
          } else if (diff == 0) {
            status = 'تنتهي اليوم';
          } else {
            status = 'متبقي $diff يوم';
          }
        }
        final entityId = doc['entity_id'];
        String vehicleName;
        if (entityType == 'truck') {
          final truck = _trucks.firstWhere(
            (t) => t['id'] == entityId,
            orElse: () => {},
          );
          vehicleName = truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? 'مركبة غير معروفة';
        } else {
          vehicleName = _trailers.firstWhere(
            (t) => t['id'] == entityId,
            orElse: () => {},
          )['plate_number']?.toString() ?? 'مركبة غير معروفة';
        }
        final categoryName = doc['document_categories']?['name']?.toString() ?? 'وثيقة';
        return ListTile(
          dense: true,
          leading: Icon(entityType == 'truck' ? Icons.local_shipping_rounded : Icons.share_rounded, size: 18),
          title: Text('$vehicleName - $categoryName'),
          subtitle: Text(status),
        );
      },
    );
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
  }

  void _toggleTheme() {
    String? userId;
    final session = _supabase.auth.currentSession;
    if (session != null) {
      userId = session.user.id;
    }
    if (userId == null) {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        userId = user.id;
      }
    }
    debugPrint('Theme toggle - userId: $userId, current mode: ${context.read<ThemeProvider>().themeMode}');
    context.read<ThemeProvider>().toggleThemeForCurrentUser(userId);
  }

  Widget _buildAdvancesDashboardCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final numberFormat = NumberFormat('#,###.00');
    final bool isPositiveBalance = _remainingBalance >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ملخص العُهد والمصاريف',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
                tooltip: 'تحديث',
                onPressed: _isLoadingAdvances ? null : _loadAdvancesSummary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingAdvances)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'إجمالي العُهد المسلمة',
                    value: '${numberFormat.format(_totalAdvancesGiven)} DH',
                    icon: Icons.send_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: 'إجمالي المصاريف المرجعة',
                    value: '${numberFormat.format(_totalExpensesReturned)} DH',
                    icon: Icons.receipt_long_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: 'الرصيد المتبقي',
                    value: '${numberFormat.format(_remainingBalance)} DH',
                    icon: isPositiveBalance ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: isPositiveBalance ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _userRole == 'Admin';
    final bool isSecretary = _userRole == 'Secretary';
    final bool isDriver = _userRole == 'Driver';

    final List<Widget> managerTabs = [
      RoleGuard(allowedRoles: ['admin'], child: const AdminDashboardScreen()),
      TreasuryScreen(isAdmin: isAdmin),
      TruckTrackingScreen(isAdmin: isAdmin),
    ];

    final List<Widget> secretaryTabs = [
      SecretaryDashboardScreen(),
      TreasuryScreen(isAdmin: isAdmin),
      TruckTrackingScreen(isAdmin: isAdmin),
    ];

    final List<Widget> driverTabs = [
      DriverTasksScreen(),
      const FuelReceiptScreen(isAdmin: false),
      TruckTrackingScreen(isAdmin: isAdmin),
    ];

    final Widget activeBody = isAdmin
        ? managerTabs[_currentTabIndex]
        : isSecretary
            ? secretaryTabs[_currentTabIndex]
            : driverTabs[_currentTabIndex];

    final String appBarTitle = isAdmin
        ? (_currentTabIndex == 0 ? 'نظام النقل الدولي' : _currentTabIndex == 1 ? 'الصندوق المالي المركزي' : 'تتبع الشاحنات مباشر')
        : isSecretary
            ? (_currentTabIndex == 0 ? 'لوحة السكرتيرة' : _currentTabIndex == 1 ? 'الصندوق المالي المركزي' : 'تتبع الشاحنات مباشر')
            : (_currentTabIndex == 0 ? 'مهامي اليوم' : _currentTabIndex == 1 ? 'مسح تذكرة وقود ذكية' : 'خريطة الطريق والـ GPS');

    final bool showDashboard = (isAdmin || isSecretary) && !isDriver;

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        centerTitle: true,
        actions: [
          if (!isDriver)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  tooltip: 'تنبيهات الانتهاء',
                  onPressed: _showAlertDialog,
                ),
                if (_expiringVisasCount + _expiringFleetDocs.length > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_expiringVisasCount + _expiringFleetDocs.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            tooltip: Theme.of(context).brightness == Brightness.dark ? 'الوضع المضيء' : 'الوضع الداكن',
            onPressed: _toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.orangeAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              _showLogoutConfirmDialog();
            },
          )
        ],
      ),

      drawer: isDriver ? null : Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              currentAccountPicture: _logoUrl != null && _logoUrl!.isNotEmpty
                  ? CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: NetworkImage(_logoUrl!),
                    )
                  : CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(Icons.local_shipping_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 36),
                    ),
              accountName: Text(isAdmin ? 'صاحب العمل (إدارة عليا)' : isSecretary ? 'السكرتير' : 'السائق', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(_userEmail, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ),

            _buildDrawerSection('لوحة التحكم والملخصات', isAdmin ? [
              _buildDrawerItem(Icons.business_rounded, 'لوحة المالك', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RoleGuard(allowedRoles: ['admin'], child: const OwnerDashboardScreen())));
              }),
              _buildDrawerItem(Icons.dashboard_customize_rounded, 'لوحة التحكم والتحليلات', () {
                Navigator.pop(context);
                setState(() => _currentTabIndex = 0);
              }),
              _buildDrawerItem(Icons.pie_chart_rounded, 'تقرير أرباح الشركة', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RoleGuard(allowedRoles: ['admin'], child: const CompanyProfitReportScreen())));
              }),
              _buildDrawerItem(Icons.settings_rounded, 'إعدادات الشركة', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RoleGuard(allowedRoles: ['admin'], child: const SystemSettingsScreen())));
              }),
            ] : []),

            _buildDrawerSection('الرحلات والسفر الدولي', [
              if (isAdmin) ...[
                _buildDrawerItem(Icons.public_rounded, 'إنشاء رحلة دولية', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InternationalTripScreen()));
                }),
                _buildDrawerItem(Icons.assignment_rounded, 'نموذج تسليم عهدة', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TripFormScreen()));
                }),
              ],
              _buildDrawerItem(Icons.list_alt_rounded, 'أوامر الرحلات', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => TripOrdersScreen(isAdmin: isAdmin)));
              }),
              _buildDrawerItem(Icons.directions_car_rounded, 'الرحلات الحالية', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => CurrentTripsScreen(isAdmin: isAdmin)));
              }),
            ]),

            _buildDrawerSection('الفواتير والمدفوعات', [
              _buildDrawerItem(Icons.receipt_long_rounded, 'الفواتير', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => InvoicesScreen(isAdmin: isAdmin)));
              }),
              _buildDrawerItem(Icons.money_off_rounded, 'الفواتير المتأخرة', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OutstandingInvoicesScreen()));
              }),
              _buildDrawerItem(Icons.notification_important_rounded, 'تذكيرات التأخر', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OverdueRemindersScreen()));
              }),
              _buildDrawerItem(Icons.timeline_rounded, 'تقرير العمر', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AgingReportScreen()));
              }),
              _buildDrawerItem(Icons.analytics_rounded, 'تقارير العملاء', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientReportsScreen()));
              }),
              _buildDrawerItem(Icons.group_rounded, 'قائمة العملاء', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ClientsScreen(isAdmin: isAdmin)));
              }),
            ]),

            _buildDrawerSection('الخزينة المالية', [
              _buildDrawerItem(Icons.account_balance_rounded, 'الخزينة وحركات الصندوق', () {
                Navigator.pop(context);
                setState(() => _currentTabIndex = 1);
              }),
              _buildDrawerItem(Icons.menu_book_rounded, 'دفتر السكرتيرة الموحد', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SecretaryLedgerScreen(userRole: _userRole.toLowerCase())));
              }),
              if (isAdmin)
                _buildDrawerItem(Icons.manage_accounts_rounded, 'إدارة الخزينة', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RoleGuard(allowedRoles: ['admin'], child: const TreasuryManagementScreen())));
                }),
              if (isAdmin)
                _buildDrawerItem(Icons.account_balance_wallet_rounded, 'قائمة الخزائن', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CashBoxManagementScreen()));
                }),
            ]),

            _buildDrawerSection('السائقين', [
              _buildDrawerItem(Icons.people_rounded, 'قائمة السائقين', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DriversScreen(isAdmin: isAdmin)));
              }),
              _buildDrawerItem(Icons.price_check_rounded, 'أجور وبونص السائقين الدوليين', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DriverSalaryScreen(isAdmin: isAdmin)));
              }),
              _buildDrawerItem(Icons.account_balance_wallet_rounded, 'شاشة العهدة الخاصة بي', () {
                Navigator.pop(context);
                final driverId = Supabase.instance.client.auth.currentUser?.id;
                if (driverId == null) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => DriverCashScreen(driverId: int.tryParse(driverId) ?? 0, driverName: _userRole == 'driver' ? 'السائق' : 'سائق')));
              }),
            ]),

            _buildDrawerSection('الأسطول والمركبات', [
              _buildNestedDrawerGroup('الشاحنات', [
                _buildNestedDrawerItem(Icons.local_shipping_rounded, 'قائمة الشاحنات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TrucksScreen(isAdmin: isAdmin)));
                }),
                _buildNestedDrawerItem(Icons.folder_rounded, 'وثائق الشاحنات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TruckDocumentsScreen(isAdmin: isAdmin)));
                }),
                _buildNestedDrawerItem(Icons.category_rounded, 'أنواع وثائق الأسطول', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentCategoriesScreen()));
                }),
              ]),
              _buildNestedDrawerGroup('المقطورات', [
                _buildNestedDrawerItem(Icons.directions_railway_rounded, 'قائمة المقطورات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TrailersScreen(isAdmin: isAdmin)));
                }),
                _buildNestedDrawerItem(Icons.description_rounded, 'وثائق المقطورات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FleetDocsScreen(isAdmin: isAdmin)));
                }),
                _buildNestedDrawerItem(Icons.build_rounded, 'صيانة المقطورات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TrailerMaintenanceScreen(isAdmin: isAdmin)));
                }),
              ]),
              _buildNestedDrawerGroup('ورش الإصلاحات', [
                _buildNestedDrawerItem(Icons.handyman_rounded, 'قائمة الورشات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProvidersScreen()));
                }),
                _buildNestedDrawerItem(Icons.account_balance_rounded, 'تقرير المصاريف حسب الورشة', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RoleGuard(allowedRoles: ['admin', 'secretary'], child: const ExpenseWorkshopReportScreen())));
                }),
                _buildNestedDrawerItem(Icons.category_rounded, 'أنواع مصروفات الإصلاحات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseCategoriesScreen()));
                }),
                _buildNestedDrawerItem(Icons.payment_rounded, 'تسوية الديون', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkshopRepairInvoicesScreen(
                    workshopId: '',
                    workshopName: 'جميع الورش',
                  )));
                }),
              ]),
            ]),

            _buildDrawerSection('التتبع والذكاء الاصطناعي', [
              _buildDrawerItem(Icons.map_rounded, 'شاشة التتبع والخرائط الحية', () {
                Navigator.pop(context);
                setState(() => _currentTabIndex = 2);
              }),
              _buildDrawerItem(Icons.document_scanner_rounded, 'مسح تذاكر المازوت (AI OCR)', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => FuelReceiptScreen(isAdmin: isAdmin)));
              }),
            ]),

            const Divider(height: 20),

            _buildDrawerGroupHeader('الإعدادات'),
            SwitchListTile(
              secondary: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              title: const Text('الوضع الداكن'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (_) => _toggleTheme(),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('إصدار المنظومة v1.0.0+1', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: showDashboard
            ? Column(
                children: [
                  _buildAdvancesDashboardCard(),
                  Expanded(child: activeBody),
                ],
              )
            : activeBody,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() => _currentTabIndex = index);
        },
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        elevation: 10,
        type: BottomNavigationBarType.fixed,
        items: isAdmin
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'الرئيسية'),
                BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'الخزينة'),
                BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'التتبع الخريطي'),
              ]
            : isSecretary
                ? const [
                    BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'الرئيسية'),
                    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'الخزينة'),
                    BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'التتبع'),
                  ]
                : const [
                    BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_rounded), label: 'مهامي'),
                    BottomNavigationBarItem(icon: Icon(Icons.document_scanner_rounded), label: 'مسح التذكرة'),
                    BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'موقعي'),
                  ],
      ),
    );
  }

  Widget _buildDrawerSection(String title, List<Widget> children) {
    final key = 'section_$title';
    final isExpanded = _expandedSections.contains(key);
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSections.remove(key);
              } else {
                _expandedSections.removeWhere((k) => k.startsWith('section_'));
                _expandedSections.add(key);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Column(children: children)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildNestedDrawerGroup(String title, List<Widget> children) {
    final key = 'nested_$title';
    final isExpanded = _expandedSections.contains(key);
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSections.remove(key);
              } else {
                _expandedSections.removeWhere((k) => k.startsWith('nested_'));
                _expandedSections.add(key);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 10, 16, 4),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Column(children: children)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildNestedDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(48, 0, 16, 0),
    );
  }

  Widget _buildDrawerGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      onTap: onTap,
      dense: true,
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج', textAlign: TextAlign.right),
        content: const Text('هل أنت متأكد من رغبتك في إغلاق الجلسة الحالية والخروج من النظام؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: const Text('خروج آمن'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
