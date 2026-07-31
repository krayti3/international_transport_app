import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../widgets/summary_card.dart';

// ignore_for_file: use_build_context_synchronously

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final ReportService _reportService = ReportService();
  Map<String, dynamic> _data = {};
  bool _isLoading = true;
  String _period = 'all'; // all, week, month

  static const _periodOptions = {
    'all': 'الكل',
    'week': 'أسبوعي',
    'month': 'شهري',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _reportService.getOwnerDashboard(period: _period);
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  double _num(String key) => (_data[key] as num?)?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final treasuryBalance = _num('treasury_balance');
    final moneyOnRoad = _num('money_on_road');
    final pendingCount = (_data['pending_count'] as num?)?.toInt() ?? 0;
    final onRoadByDriver =
        List<Map<String, dynamic>>.from(_data['on_road_by_driver'] ?? []);
    final truckExpenses =
        List<Map<String, dynamic>>.from(_data['truck_expenses'] ?? []);

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة صاحب العمل')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    Align(
                      alignment: Alignment.centerRight,
                      child: SegmentedButton<String>(
                        segments: _periodOptions.entries
                            .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                            .toList(),
                        selected: {_period},
                        onSelectionChanged: (values) {
                          setState(() => _period = values.first);
                          _loadData();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top summary cards
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: 'صندوق السكرتيرة',
                            value: '${treasuryBalance.toStringAsFixed(2)} DH',
                            color: treasuryBalance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryCard(
                            title: 'أموال في الطريق',
                            value: '${moneyOnRoad.toStringAsFixed(2)} DH',
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SummaryCard(
                      title: 'رحلات جارية',
                      value: '$pendingCount رحلة',
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 24),
                    const Text('الأموال في الطريق حسب السائق',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (onRoadByDriver.isEmpty)
                      const Text('لا توجد رحلات جارية حالياً')
                    else
                      ...onRoadByDriver.map((e) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const Icon(Icons.person, color: Colors.blue),
                              title: Text(e['driver_name']?.toString() ?? ''),
                              trailing: Text(
                                '${(e['amount'] as double).toStringAsFixed(2)} DH',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ),
                          )),

                    const SizedBox(height: 24),
                    const Text('تقرير مصاريف الشاحنات',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('حسب الفترة: ${_periodOptions[_period]}',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    if (truckExpenses.isEmpty)
                      const Text('لا توجد مصاريف مسجلة في هذه الفترة')
                    else
                      ...truckExpenses.map((e) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const Icon(Icons.local_shipping, color: Colors.indigo),
                               title: Text(e['truck_plate']?.toString() ?? '', textDirection: TextDirection.ltr, textAlign: TextAlign.left),
                              trailing: Text(
                                '${(e['amount'] as double).toStringAsFixed(2)} DH',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),
    );
  }
}
