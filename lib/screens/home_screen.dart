import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

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
import 'truck_maintenance_screen.dart';
import 'truck_documents_screen.dart';
import 'fleet_alerts_screen.dart';
import 'clients_screen.dart';
import 'driver_tasks_screen.dart';
import 'fleet_docs_screen.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalAlerts = _expiringVisasCount + _expiringFleetDocs.length;
    if (totalAlerts == 0) return;

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 3,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.orange),
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
                      _buildVisaList(isDark),
                      _buildFleetDocList(_expiringTruckDocs, 'truck', isDark),
                      _buildFleetDocList(_expiringTrailerDocs, 'trailer', isDark),
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

  Widget _buildVisaList(bool isDark) {
    if (_expiringVisas.isEmpty) {
      return Center(child: Text('لا توجد تأشيرات منتهية', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])));
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

  Widget _buildFleetDocList(List<Map<String, dynamic>> docs, String entityType, bool isDark) {
    if (docs.isEmpty) {
      return Center(child: Text('لا توجد وثائق منتهية', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])));
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

  Widget _buildAdvancesDashboardCard(bool isDark) {
    final numberFormat = NumberFormat('#,###.00');
    final bool isPositiveBalance = _remainingBalance >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
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
              Icon(Icons.account_balance_wallet_rounded, color: Colors.teal[600], size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ملخص العُهد والمصاريف',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.blueGrey[900],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: Colors.teal[600]),
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
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: 'إجمالي المصاريف المرجعة',
                    value: '${numberFormat.format(_totalExpensesReturned)} DH',
                    icon: Icons.receipt_long_rounded,
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: 'الرصيد المتبقي',
                    value: '${numberFormat.format(_remainingBalance)} DH',
                    icon: isPositiveBalance ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: isPositiveBalance ? Colors.green : Colors.red,
                    isDark: isDark,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.blueGrey[900],
        foregroundColor: Colors.white,
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
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.orangeAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              _showLogoutConfirmDialog();
            },
          )
        ],
      ),

      drawer: isDriver ? null : Drawer(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.blueGrey[900],
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.teal[700],
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 36),
              ),
              accountName: Text(isAdmin ? 'صاحب العمل (إدارة عليا)' : isSecretary ? 'السكرتير' : 'السائق', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(_userEmail, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
            ),

            if (isAdmin) ...[
              _buildDrawerGroupHeader('لوحة التحكم والملخصات'),
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
              _buildDrawerItem(Icons.settings_rounded, 'إعدادات النظام', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RoleGuard(allowedRoles: ['admin'], child: const SystemSettingsScreen())));
              }),
              const Divider(height: 20),
            ],

            _buildDrawerGroupHeader('الرحلات والسفر الدولي'),
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

            const Divider(height: 20),

            _buildDrawerGroupHeader('الفواتير والمدفوعات'),
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

            const Divider(height: 20),

            _buildDrawerGroupHeader('الخزينة المالية'),
            _buildDrawerItem(Icons.account_balance_rounded, 'الخزينة وحركات الصندوق', () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 1);
            }),
            _buildDrawerItem(Icons.menu_book_rounded, 'دفتر السكرتيرة الموحد', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => SecretaryLedgerScreen(userRole: _userRole.toLowerCase())));
            }),
            if (isAdmin) ...[
              _buildDrawerItem(Icons.manage_accounts_rounded, 'إدارة الخزينة', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RoleGuard(allowedRoles: ['admin'], child: const TreasuryManagementScreen())));
              }),
            ],

            const Divider(height: 20),

            _buildDrawerGroupHeader('الأسطول والمركبات'),
            _buildDrawerItem(Icons.local_shipping_rounded, 'الشاحنات', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => TrucksScreen(isAdmin: isAdmin)));
            }),
            _buildDrawerItem(Icons.people_rounded, 'السائقين', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DriversScreen(isAdmin: isAdmin)));
            }),
            _buildDrawerItem(Icons.build_rounded, 'صيانة الشاحنات', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => TruckMaintenanceScreen(isAdmin: isAdmin)));
            }),
            _buildDrawerItem(Icons.folder_rounded, 'وثائق الشاحنات', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => TruckDocumentsScreen(isAdmin: isAdmin)));
            }),
            _buildDrawerItem(Icons.description_rounded, 'وثائق الأسطول', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => FleetDocsScreen(isAdmin: isAdmin)));
            }),
            _buildDrawerItem(Icons.warning_rounded, 'تنبيهات الأسطول', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetAlertsScreen()));
            }),

            const Divider(height: 20),

            _buildDrawerGroupHeader('التتبع والذكاء الاصطناعي'),
            _buildDrawerItem(Icons.map_rounded, 'شاشة التتبع والخرائط الحية', () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 2);
            }),
            _buildDrawerItem(Icons.document_scanner_rounded, 'مسح تذاكر المازوت (AI OCR)', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => FuelReceiptScreen(isAdmin: isAdmin)));
            }),
            _buildDrawerItem(Icons.price_check_rounded, 'أجور وبونص السائقين الدوليين', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DriverSalaryScreen(isAdmin: isAdmin)));
            }),

            const Divider(height: 20),

            _buildDrawerGroupHeader('العملاء'),
            _buildDrawerItem(Icons.group_rounded, 'قائمة العملاء', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ClientsScreen(isAdmin: isAdmin)));
            }),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('إصدار المنظومة v1.0.0+1', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11)),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: showDashboard
            ? Column(
                children: [
                  _buildAdvancesDashboardCard(isDark),
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
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        selectedItemColor: Colors.teal[600],
        unselectedItemColor: Colors.grey[500],
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

  Widget _buildDrawerGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(title, style: TextStyle(color: Colors.teal[600], fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal[400], size: 22),
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
  final bool isDark;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
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
              color: isDark ? Colors.grey[300] : Colors.blueGrey[700],
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
