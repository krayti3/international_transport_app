import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;

  // دالة لجلب خلاصة البيانات المالية والتشغيلية بشكل موحد وحي من جدول treasury_transactions
  Stream<Map<String, dynamic>> _getDashboardStatsStream() {
    return _supabase
        .from('treasury_transactions')
        .stream(primaryKey: ['id'])
        .map((transactions) {
          double totalIncome = 0.0;
          double totalExpense = 0.0;
          double fuelExpense = 0.0;
          double salaryExpense = 0.0;
          double maintenanceExpense = 0.0;
          double generalExpense = 0.0;

          for (var tx in transactions) {
            final double amt = (tx['amount'] ?? 0.0).toDouble();
            final String type = (tx['type'] ?? '').toString();

            // تصنيف الأنواع الحقيقية: المداخيل vs المصاريف
            if (type == 'capital_injection' || type == 'trip_revenue') {
              totalIncome += amt;
            } else {
              totalExpense += amt;
              // تصنيف المصاريف حسب النوع الحقيقي في المخطط
              switch (type) {
                case 'salary':
                  salaryExpense += amt;
                  break;
                case 'trip_expense':
                  fuelExpense += amt;
                  break;
                case 'office_expense':
                case 'owner_withdrawal':
                default:
                  generalExpense += amt;
                  break;
              }
            }
          }

          double netBalance = totalIncome - totalExpense;

          return {
            'netBalance': netBalance,
            'totalIncome': totalIncome,
            'totalExpense': totalExpense,
            'fuelExpense': fuelExpense,
            'salaryExpense': salaryExpense,
            'maintenanceExpense': maintenanceExpense,
            'generalExpense': generalExpense,
            'totalTransactions': transactions.length,
          };
        });
  }

  // دالة منفصلة لجلب الأموال المعلقة في الطريق (العهد النشطة غير المسواة من جدول advances)
  Stream<double> _getPendingAdvancesStream() {
    return _supabase
        .from('advances')
        .stream(primaryKey: ['id'])
        .map((advances) {
          double pendingAmount = 0.0;
          for (var adv in advances) {
            // تجاهل العُهد المحذوفة والمُسوّاة
            if (adv['is_deleted'] == true) continue;
            if (adv['status']?.toString() != 'pending') continue;

            final double given = (adv['amount_given'] ?? 0.0).toDouble();
            final double returned = (adv['amount_returned'] ?? 0.0).toDouble();
            pendingAmount += (given - returned);
          }
          return pendingAmount;
        });
  }

  Stream<double> _getMaintenanceStream() {
    return _supabase
        .from('truck_maintenance')
        .stream(primaryKey: ['id'])
        .map((maintenances) {
          double total = 0.0;
          for (var m in maintenances) {
            total += (m['amount'] as num?)?.toDouble() ?? 0.0;
          }
          return total;
        });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👑 الترحيب والترويسة الإدارية
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لوحة التحكم الإدارية العليا',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.blueGrey[900]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الملخص المالي واللوجستي والسيولة النقدية الحية للشركة',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                                ),
                               ],
                              ),
                    ),
                   const SizedBox(width: 16),
                  CircleAvatar(
                    backgroundColor: Colors.blue[700]!.withValues(alpha: 0.15),
                    radius: 24,
                    child: Icon(Icons.admin_panel_settings_rounded, color: Colors.blue[400], size: 28),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // 📊 دفق الإحصائيات الرئيسي
              StreamBuilder<Map<String, dynamic>>(
                stream: _getDashboardStatsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                  }

                  final stats = snapshot.data ?? {
                    'netBalance': 0.0, 'totalIncome': 0.0, 'totalExpense': 0.0,
                    'fuelExpense': 0.0, 'salaryExpense': 0.0, 'maintenanceExpense': 0.0,
                    'generalExpense': 0.0, 'totalTransactions': 0
                  };

                  return StreamBuilder<double>(
                    stream: _getMaintenanceStream(),
                    builder: (context, maintSnapshot) {
                      final double maintenanceExpense = maintSnapshot.data ?? 0.0;

                      return StreamBuilder<double>(
                        stream: _getPendingAdvancesStream(),
                        builder: (context, advSnapshot) {
                          final double pendingInWay = advSnapshot.data ?? 0.0;

                      // 💰 كروت المؤشرات المالية الكبرى (متجاوبة)
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isDesktop)
                            Row(
                              children: [
                                _buildKpiCard('صافي رصيد الصندوق والبنك', '${NumberFormat('#,###.00').format(stats['netBalance'])} DH', Icons.account_balance_wallet_rounded, Colors.green, isDark),
                                const SizedBox(width: 12),
                                _buildKpiCard('أموال معلقة في الطريق (عُهد للسائقين)', '${NumberFormat('#,###.00').format(pendingInWay)} DH', Icons.local_shipping_rounded, Colors.orange, isDark),
                                const SizedBox(width: 12),
                                _buildKpiCard('إجمالي التدفقات الخارجة (المصاريف)', '${NumberFormat('#,###.00').format(stats['totalExpense'])} DH', Icons.trending_down_rounded, Colors.red, isDark),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildKpiCard('صافي رصيد الصندوق والبنك', '${NumberFormat('#,###.00').format(stats['netBalance'])} DH', Icons.account_balance_wallet_rounded, Colors.green, isDark, fullWidth: true),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildKpiCard('أموال في الطريق', '${NumberFormat('#,###.00').format(pendingInWay)} DH', Icons.local_shipping_rounded, Colors.orange, isDark),
                                    const SizedBox(width: 12),
                                    _buildKpiCard('المصاريف الكلية', '${NumberFormat('#,###.00').format(stats['totalExpense'])} DH', Icons.trending_down_rounded, Colors.red, isDark),
                                  ],
                                )
                              ],
                            ),

                          const SizedBox(height: 28),

                          // 📉 قسم الرسم البياني المصغر لتشريح المصاريف التشغيلية
                          Text(
                            'تشريح وتحليل المصاريف التشغيلية واللوجستية',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.blueGrey[800]),
                          ),
                          const SizedBox(height: 12),

                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                            ),
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  _buildExpenseProgressBar('وقود ومازوت الرحلات الدولية', stats['fuelExpense'], stats['totalExpense'], Colors.amber[700]!),
                                  const SizedBox(height: 16),
                                  _buildExpenseProgressBar('رواتب وأجور وبونص السائقين', stats['salaryExpense'], stats['totalExpense'], Colors.teal),
                                  const SizedBox(height: 16),
                                  _buildExpenseProgressBar('صيانة المقطورات وقطع الغيار الطارئة', maintenanceExpense, stats['totalExpense'], Colors.red[400]!),
                                  const SizedBox(height: 16),
                                  _buildExpenseProgressBar('مصاريف عمومية وإدارية ومكتبية', stats['generalExpense'], stats['totalExpense'], Colors.blue[400]!),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 📈 كروت إحصاء المعاملات السريعة
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('نبض النظام الكلي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.blueGrey[800])),
                              Chip(
                                label: Text('إجمالي العمليات الموثقة: ${stats['totalTransactions']}'),
                                backgroundColor: isDark ? Colors.blueGrey.withValues(alpha: 0.25) : Colors.blueGrey.withValues(alpha: 0.12),
                              ),
                            ],
                          ),
                              ],
                            ),
                          },
                        ),
                      },
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      );
}

  // بناء كروت الـ KPI المتقدمة والملونة ذكياً
  Widget _buildKpiCard(String title, String value, IconData icon, Color color, bool isDark, {bool fullWidth = false}) {
    final cardWidget = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                radius: 18,
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: cardWidget) : Expanded(child: cardWidget);
  }

  // خوارزمية بناء أشرطة تقدم مخصصة وحساب النسب المئوية للمصاريف برمجياً بدون مكاتب خارجية
  Widget _buildExpenseProgressBar(String title, double categoryAmount, double totalExpense, Color color) {
    // منع القسمة على صفر إذا لم تكن هناك أي مصاريف مسجلة بعد
    final double percentage = totalExpense > 0 ? (categoryAmount / totalExpense) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Text(
              '${NumberFormat('#,###.00').format(categoryAmount)} DH (${(percentage * 100).toStringAsFixed(1)}%)',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
