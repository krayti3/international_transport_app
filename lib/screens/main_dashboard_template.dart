import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/theme_provider.dart';
import '../widgets/language_switcher.dart';

// استيراد الشاشات الخاصة بك
import '../widgets/role_guard.dart';
import 'home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'clients_screen.dart';
import 'trip_orders_screen.dart';
import 'invoices_screen.dart';
import 'treasury_screen.dart';
import 'fuel_receipt_screen.dart';
import 'truck_tracking_screen.dart';
import 'driver_salary_screen.dart';
import 'workshop_repairs_screen.dart';

/// عنصر واحد في قائمة التنقل (يربط بين العنوان والأيقونة والصفحة).
class _NavEntry {
  final String title;
  final String shortTitle; // عنوان مختصر يظهر في شريط الهاتف السفلي
  final IconData icon;
  final Widget page;

  const _NavEntry({
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.page,
  });
}

/// القالب الرئيسي (Shell) الذي يحتوي كل شاشات المشروع.
///
/// - على شاشات الحاسوب العريضة (ويندوز): قائمة جانبية أنيقة (Sidebar).
/// - على الهواتف: شريط سفلي مبسّط (Bottom Navigation) يناسب إصبع اليد.
///
/// ملاحظة مهمة: كل الشاشات المُضمّنة هنا تملك (Scaffold + AppBar) خاصاً بها،
/// لذلك لا يضع هذا القالب شريطاً علوياً (AppBar) خاصاً به حتى لا يظهر شريطان
/// فوق بعضهما. الإجراءات العامة (المظهر / اللغة / تسجيل الخروج) موجودة داخل
/// القائمة الجانبية على الحاسوب، وفي صفحة "الحساب" على الهاتف.
class MainDashboardTemplate extends StatefulWidget {
  final bool isAdmin;
  final String? role;
  final Future<void> Function()? onSignOut;

  const MainDashboardTemplate({
    super.key,
    this.isAdmin = false,
    this.role,
    this.onSignOut,
  });

  @override
  State<MainDashboardTemplate> createState() => _MainDashboardTemplateState();
}

class _MainDashboardTemplateState extends State<MainDashboardTemplate> {
  int _selectedIndex = 0;

  bool get _isAdmin => widget.isAdmin;

  /// كل الصفحات المتاحة داخل القالب (تُبنى مرة واحدة وتُحفظ حالتها بواسطة IndexedStack).
  late final List<_NavEntry> _entries = _buildEntries();

  List<_NavEntry> _buildEntries() {
    return [
      // الصفحة الرئيسية: شبكة كل الأقسام (تحافظ على الوصول لكل شاشات المشروع).
      _NavEntry(
        title: 'الرئيسية',
        shortTitle: 'الرئيسية',
        icon: Icons.grid_view_rounded,
        page: const HomeScreen(),
      ),
      // لوحة تحكم المدير (للمدير فقط).
      if (_isAdmin)
        _NavEntry(
          title: 'لوحة التحكم',
          shortTitle: 'اللوحة',
          icon: Icons.dashboard_rounded,
          page: RoleGuard(allowedRoles: ['admin'], child: const AdminDashboardScreen()),
        ),
      _NavEntry(
        title: 'إدارة الزبائن',
        shortTitle: 'الزبائن',
        icon: Icons.people_alt_rounded,
        page: ClientsScreen(isAdmin: _isAdmin),
      ),
      _NavEntry(
        title: 'الرحلات والطلبات',
        shortTitle: 'الرحلات',
        icon: Icons.local_shipping_rounded,
        page: TripOrdersScreen(isAdmin: _isAdmin),
      ),
      _NavEntry(
        title: 'الفواتير والمالية',
        shortTitle: 'الفواتير',
        icon: Icons.receipt_long_rounded,
        page: InvoicesScreen(isAdmin: _isAdmin),
      ),
      _NavEntry(
        title: 'فواتير الورش',
        shortTitle: 'ورش الإصلاح',
        icon: Icons.build_rounded,
        page: const WorkshopRepairInvoicesScreen(
          workshopId: '',
          workshopName: 'جميع الورش',
        ),
      ),
      _NavEntry(
        title: 'الخزينة والصندوق',
        shortTitle: 'الخزينة',
        icon: Icons.account_balance_wallet_rounded,
        page: TreasuryScreen(isAdmin: _isAdmin),
      ),
      const _NavEntry(
        title: 'سجل تذاكر الوقود',
        shortTitle: 'الوقود',
        icon: Icons.local_gas_station_rounded,
        page: FuelReceiptScreen(),
      ),
      _NavEntry(
        title: 'تتبع الشاحنات',
        shortTitle: 'التتبع',
        icon: Icons.location_on_rounded,
        page: TruckTrackingScreen(isAdmin: _isAdmin),
      ),
      _NavEntry(
        title: 'رواتب السائقين',
        shortTitle: 'الرواتب',
        icon: Icons.payments_rounded,
        page: DriverSalaryScreen(isAdmin: _isAdmin),
      ),
    ];
  }

  /// الأقسام التي تظهر في الشريط السفلي للهاتف (مختصرة حتى لا يزدحم الشريط).
  /// نعرض أهم الأقسام، وباقي الأقسام تبقى متاحة من صفحة "الرئيسية".
  List<int> get _mobileEntryIndexes {
    // نأخذ أول 4 أقسام كحد أقصى ثم نضيف زر "الحساب".
    final count = _entries.length < 4 ? _entries.length : 4;
    return List<int>.generate(count, (i) => i);
  }

  void _openThemeSwitch() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    Provider.of<ThemeProvider>(context, listen: false).toggleThemeForCurrentUser(userId);
  }

  Future<void> _confirmSignOut() async {
    if (widget.onSignOut == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد بالتأكيد تسجيل الخروج من الحساب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onSignOut!.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    final pages = _entries.map((e) => e.page).toList();

    return Scaffold(
      body: Row(
        children: [
          // 🖥️ القائمة الجانبية الأنيقة على الحاسوب.
          if (isDesktop) _buildSidebar(context),

          // الشاشة الفعلية المعروضة حالياً (تحافظ على حالتها في الخلفية).
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ),
        ],
      ),

      // 📱 الشريط السفلي الذكي للهاتف فقط.
      bottomNavigationBar: isDesktop ? null : _buildMobileNav(),
    );
  }

  // ===================== القائمة الجانبية (حاسوب) =====================
  Widget _buildSidebar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          right: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // ترويسة النظام.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.directions_bus_filled_rounded, color: accent, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'النقل الدولي واللوجستيات',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // معلومات المستخدم الحالي.
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.person_rounded, color: colorScheme.onPrimary),
            ),
            title: Text(
              _isAdmin ? 'المسؤول المالي' : 'موظف السكرتارية',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _isAdmin ? 'صلاحيات كاملة' : 'صلاحيات محدودة',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const Divider(indent: 16, endIndent: 16, height: 24),

          // أزرار القائمة الجانبية.
          Expanded(
            child: ListView.builder(
              itemCount: _entries.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final item = _entries[index];
                final isSelected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor: isSelected
                        ? colorScheme.primaryContainer.withAlpha(77)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(
                      item.icon,
                      color: isSelected ? accent : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? accent : null,
                      ),
                    ),
                    onTap: () => setState(() => _selectedIndex = index),
                  ),
                );
              },
            ),
          ),

          const Divider(indent: 16, endIndent: 16, height: 8),
          // الإجراءات العامة أسفل القائمة.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: Theme.of(context).brightness == Brightness.dark ? 'الوضع المضيء' : 'الوضع الداكن',
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  ),
                  onPressed: _openThemeSwitch,
                ),
                const LanguageSwitcher(),
                Chip(
                  label: Text(
                    Platform.isWindows ? 'نسخة الحاسوب' : 'نسخة الهاتف',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
                if (widget.onSignOut != null)
                  IconButton(
                    tooltip: 'تسجيل الخروج',
                    icon: Icon(Icons.logout_rounded, color: colorScheme.error),
                    onPressed: _confirmSignOut,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ===================== الشريط السفلي (هاتف) =====================
  Widget _buildMobileNav() {
    final mobileIndexes = _mobileEntryIndexes;

    // موضع العنصر المختار داخل الشريط السفلي، وإلا يقع على زر "الحساب".
    int navSelected = mobileIndexes.indexOf(_selectedIndex);
    if (navSelected < 0) navSelected = mobileIndexes.length; // زر الحساب

    final destinations = <NavigationDestination>[
      for (final idx in mobileIndexes)
        NavigationDestination(
          icon: Icon(_entries[idx].icon),
          label: _entries[idx].shortTitle,
        ),
      const NavigationDestination(
        icon: Icon(Icons.menu_rounded),
        label: 'الحساب',
      ),
    ];

    return NavigationBar(
      selectedIndex: navSelected,
      onDestinationSelected: (i) {
        if (i < mobileIndexes.length) {
          setState(() => _selectedIndex = mobileIndexes[i]);
        } else {
          _showMobileMoreSheet();
        }
      },
      destinations: destinations,
    );
  }

  /// قائمة "الحساب / المزيد" على الهاتف: بقية الأقسام + الإجراءات العامة.
  void _showMobileMoreSheet() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final mobileIndexes = _mobileEntryIndexes.toSet();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // بقية الأقسام غير الظاهرة في الشريط السفلي.
                for (int i = 0; i < _entries.length; i++)
                  if (!mobileIndexes.contains(i))
                    ListTile(
                      leading: Icon(_entries[i].icon),
                      title: Text(_entries[i].title),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedIndex = i);
                      },
                    ),
                const Divider(),
                // الإجراءات العامة.
                SwitchListTile(
                  secondary: Icon(
                    Theme.of(ctx).brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  ),
                  title: const Text('الوضع الداكن'),
                  value: Theme.of(ctx).brightness == Brightness.dark,
                  onChanged: (_) {
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    themeProvider.toggleThemeForCurrentUser(userId);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.language, color: colorScheme.primary),
                  title: Text('اللغة', style: TextStyle(color: colorScheme.onSurface)),
                  trailing: const LanguageSwitcher(),
                ),
                if (widget.onSignOut != null)
                  ListTile(
                    leading: Icon(Icons.logout_rounded, color: colorScheme.error),
                    title: Text(
                      'تسجيل الخروج',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmSignOut();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
