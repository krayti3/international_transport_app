import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class DriverSalaryScreen extends StatefulWidget {
  final bool isAdmin;
  const DriverSalaryScreen({super.key, required this.isAdmin});

  @override
  State<DriverSalaryScreen> createState() => _DriverSalaryScreenState();
}

class _DriverSalaryScreenState extends State<DriverSalaryScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  final _driverNameController = TextEditingController();
  final _baseSalaryController = TextEditingController();
  final _bonusController = TextEditingController();
  final _deductionsController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isCalculating = false;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _drivers = [];
  Map<String, Map<String, dynamic>> _salaryCache = {};
  List<Map<String, dynamic>> _cashBoxes = [];
  int? _selectedCashBoxId;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _loadCashBoxes();
  }

  Future<void> _loadCashBoxes() async {
    final boxes = await _supabaseService.getCashBoxes();
    if (mounted) {
      setState(() {
        _cashBoxes = boxes;
        _selectedCashBoxId = boxes.isNotEmpty ? boxes.first['id'] : null;
      });
    }
  }

  Future<void> _loadDrivers() async {
    setState(() => _isCalculating = true);
    final drivers = await _supabaseService.getDrivers();
    if (!mounted) return;
    setState(() {
      _drivers = drivers;
      _isCalculating = false;
    });
    await _calculateAllSalaries();
  }

  Future<void> _calculateAllSalaries() async {
    final Map<String, Map<String, dynamic>> cache = {};
    for (final driver in _drivers) {
      final driverId = driver['id']?.toString() ?? '';
      if (driverId.isEmpty) continue;
      final result = await _supabaseService.calculateDriverSalary(
        driverId: driverId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      cache[driverId] = result;
    }
    if (!mounted) return;
    setState(() => _salaryCache = cache);
  }

  Future<void> _saveManualSalary() async {
    final driverName = _driverNameController.text.trim();
    final baseText = _baseSalaryController.text.trim();
    final bonusText = _bonusController.text.trim();
    final deductionsText = _deductionsController.text.trim();
    final notes = _notesController.text.trim();

    if (driverName.isEmpty || baseText.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final double base = double.tryParse(baseText) ?? 0.0;
      final double bonus = double.tryParse(bonusText) ?? 0.0;
      final double deductions = double.tryParse(deductionsText) ?? 0.0;
      final double netSalary = (base + bonus) - deductions;
      final monthLabel = DateFormat('MMMM yyyy', 'ar').format(DateTime(_selectedYear, _selectedMonth));

      int? driverId;
      final matched = _drivers.where((d) => (d['name'] ?? '').toString().toLowerCase() == driverName.toLowerCase()).toList();
      if (matched.isNotEmpty) {
        driverId = matched.first['id'] as int?;
      }

      final salaryData = <String, dynamic>{
        'driver_name': driverName,
        'month': monthLabel,
        'base_salary': base,
        'bonus_amount': bonus,
        'deductions': deductions,
        'net_salary': netSalary,
        'notes': notes,
        if (driverId != null) 'driver_id': driverId,
        'year': _selectedYear,
        'total_salary': netSalary,
        'completed_trips_count': 0,
      };

      await _insertWithSchemaTolerance(
        _supabase.from('driver_salaries'),
        salaryData,
      );

      await _supabaseService.addTreasuryTransaction(
        netSalary,
        'salary',
        'صرف راتب وشهرية السائق: $driverName ($monthLabel)',
        cashBoxId: _selectedCashBoxId,
      );

      _driverNameController.clear();
      _baseSalaryController.clear();
      _bonusController.clear();
      _deductionsController.text = '0';
      _notesController.clear();

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم احتساب وصرف الراتب وتحديث الخزينة فورياً'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء صرف الراتب: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _insertWithSchemaTolerance(
    SupabaseQueryBuilder query,
    Map<String, dynamic> data,
  ) async {
    var attempt = Map<String, dynamic>.from(data);
    String? lastFilledColumn;
    for (var i = 0; i < 10; i++) {
      try {
        await query.insert(attempt);
        return;
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST204') {
          final match = RegExp(r"Could not find the '(\w+)' column").firstMatch(e.message);
          final column = match?.group(1);
          if (column != null && attempt.containsKey(column)) {
            attempt.remove(column);
            continue;
          }
        } else if (e.code == '23502') {
          final match = RegExp(r'null value in column "(\w+)"').firstMatch(e.message);
          final column = match?.group(1);
          if (column != null) {
            attempt[column] = '';
            lastFilledColumn = column;
            continue;
          }
        } else if (e.code == '22P02') {
          if (lastFilledColumn != null) {
            attempt[lastFilledColumn] = 0;
            continue;
          }
        }
        rethrow;
      }
    }
    throw Exception('تعذّر الحفظ بسبب اختلاف في مخطط قاعدة البيانات');
  }

  void _showPaySalaryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('احتساب وصرف شهرية سائق', textAlign: TextAlign.right),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _driverNameController,
                  decoration: const InputDecoration(labelText: 'اسم السائق بالكامل', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _baseSalaryController,
                        decoration: const InputDecoration(labelText: 'الراتب الأساسي (€)', prefixIcon: Icon(Icons.money)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _bonusController,
                        decoration: const InputDecoration(labelText: 'البونص / المكافآت (€)', prefixIcon: Icon(Icons.add_circle_outline_rounded)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deductionsController,
                  decoration: const InputDecoration(labelText: 'خصم السلفيات والعُهد المعلقة (€)', prefixIcon: Icon(Icons.remove_circle_outline_rounded)),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                 const SizedBox(height: 12),
                 DropdownButtonFormField<String?>(
                   initialValue: _selectedCashBoxId?.toString(),
                   decoration: const InputDecoration(labelText: 'الصندوق المصدر'),
                   items: _cashBoxes.isEmpty
                       ? null
                       : _cashBoxes.map((b) {
                           return DropdownMenuItem<String?>(
                             value: b['id']?.toString(),
                             child: Text(b['label']?.toString() ?? ''),
                           );
                         }).toList(),
                   onChanged: (v) {
                     setState(() => _selectedCashBoxId = v == null ? null : int.tryParse(v));
                   },
                 ),
                 const SizedBox(height: 12),
                 TextField(
                   controller: _notesController,
                   decoration: const InputDecoration(labelText: 'ملاحظات تفصيلية (مثال: بونص رحلة فرنسا)', prefixIcon: Icon(Icons.comment_bank_rounded)),
                 ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveManualSalary,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تأكيد الصرف والترحيل'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(DateTime(_selectedYear, _selectedMonth));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('رواتب السائقين'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'احتساب تلقائي', icon: Icon(Icons.calculate_rounded)),
              Tab(text: 'صرف يدوي وسجل', icon: Icon(Icons.price_check_rounded)),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'الشهر',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedMonth,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('يناير')),
                        DropdownMenuItem(value: 2, child: Text('فبراير')),
                        DropdownMenuItem(value: 3, child: Text('مارس')),
                        DropdownMenuItem(value: 4, child: Text('أبريل')),
                        DropdownMenuItem(value: 5, child: Text('مايو')),
                        DropdownMenuItem(value: 6, child: Text('يونيو')),
                        DropdownMenuItem(value: 7, child: Text('يوليو')),
                        DropdownMenuItem(value: 8, child: Text('أغسطس')),
                        DropdownMenuItem(value: 9, child: Text('سبتمبر')),
                        DropdownMenuItem(value: 10, child: Text('أكتوبر')),
                        DropdownMenuItem(value: 11, child: Text('نوفمبر')),
                        DropdownMenuItem(value: 12, child: Text('ديسمبر')),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _selectedMonth = value);
                        await _calculateAllSalaries();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'السنة',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedYear,
                      items: List.generate(5, (index) {
                        final year = DateTime.now().year - 2 + index;
                        return DropdownMenuItem(value: year, child: Text('$year'));
                      }),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _selectedYear = value);
                        await _calculateAllSalaries();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAutoSalaryTab(isDark, monthLabel),
                  _buildManualSalaryTab(isDark),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showPaySalaryDialog,
          icon: const Icon(Icons.price_check_rounded),
          label: const Text('صرف الراتب والبونص'),
          backgroundColor: Colors.teal[700],
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAutoSalaryTab(bool isDark, String monthLabel) {
    if (_isCalculating) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_drivers.isEmpty) {
      return const Center(child: Text('لا يوجد سائقين مسجلين'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        final driverId = driver['id']?.toString() ?? '';
        final salary = _salaryCache[driverId];
        final name = driver['name'] ?? 'بدون اسم';
        final baseSalary = salary?['base_salary']?.toDouble() ?? 0.0;
        final bonusPercentage = salary?['bonus_percentage']?.toDouble() ?? 0.0;
        final completedTrips = salary?['completed_trips_count']?.toInt() ?? 0;
        final totalTripValue = salary?['total_trip_value']?.toDouble() ?? 0.0;
        final bonusAmount = salary?['bonus_amount']?.toDouble() ?? 0.0;
        final totalSalary = salary?['total_salary']?.toDouble() ?? 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'الراتب الإجمالي: ${totalSalary.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الراتب الأساسي: ${baseSalary.toStringAsFixed(2)} €'),
                        Text('نسبة البونص: $bonusPercentage%'),
                        Text('عدد الرحلات المكتملة: $completedTrips'),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('قيمة الرحلات: ${totalTripValue.toStringAsFixed(2)} €'),
                        Text('مبلغ البونص: ${bonusAmount.toStringAsFixed(2)} €'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualSalaryTab(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('driver_salaries')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('خطأ في جلب بيانات الأجور: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final salaries = snapshot.data ?? [];
        if (salaries.isEmpty) {
          return const Center(child: Text('لا توجد رواتب مسجلة ومصروفة حالياً.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: salaries.length,
          itemBuilder: (context, index) {
            final salary = salaries[index];
            final double net = (salary['net_salary'] ?? salary['total_salary'] ?? 0.0).toDouble();
            final double base = (salary['base_salary'] ?? 0.0).toDouble();
            final double bonus = (salary['bonus_amount'] ?? 0.0).toDouble();
            final double deduction = (salary['deductions'] ?? 0.0).toDouble();
            final String driverName = salary['driver_name'] ?? 'سائق غير محدد';
            final String month = salary['month'] ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
              ),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: ExpansionTile(
                iconColor: Colors.teal,
                title: Text(
                  driverName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  '$month | الصافي المالي: ${NumberFormat('#,###.00').format(net)} €',
                  style: TextStyle(color: Colors.teal[400], fontSize: 13, fontWeight: FontWeight.w500),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الراتب الأساسي الثابت:', style: TextStyle(color: Colors.grey[500])),
                            Text('${NumberFormat('#,###.00').format(base)} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('بونص ومكافآت خطوط النقل الدولي (+):', style: TextStyle(color: Colors.grey[500])),
                            Text('${NumberFormat('#,###.00').format(bonus)} €', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('خصم عُهد وسلفيات (-):', style: TextStyle(color: Colors.grey[500])),
                            Text('${NumberFormat('#,###.00').format(deduction)} €', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (salary['notes'] != null && salary['notes'].toString().isNotEmpty) ...[
                          const Divider(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تفاصيل الحساب والتفويض: ', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              Expanded(child: Text(salary['notes'], style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic))),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _baseSalaryController.dispose();
    _bonusController.dispose();
    _deductionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
