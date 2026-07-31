import 'package:flutter/material.dart';
import '../services/fleet_service.dart';
import 'vehicle_expense_screen.dart';

class ExpenseCategoryDetailScreen extends StatefulWidget {
  final String expenseType;
  const ExpenseCategoryDetailScreen({super.key, required this.expenseType});

  @override
  State<ExpenseCategoryDetailScreen> createState() => _ExpenseCategoryDetailScreenState();
}

class _ExpenseCategoryDetailScreenState extends State<ExpenseCategoryDetailScreen> {
  final FleetService _fleetService = FleetService();
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final maintenances = await _fleetService.getMaintenancesByExpenseType(widget.expenseType);
      final truckIds = <int>{};
      final trailerIds = <int>{};
      for (final m in maintenances) {
        final vType = m['vehicle_type']?.toString() ?? '';
        final vId = m['vehicle_id'] as int?;
        if (vType.isEmpty || vId == null) continue;
        if (vType == 'truck') truckIds.add(vId);
        if (vType == 'trailer') trailerIds.add(vId);
      }
      final trucks = truckIds.isEmpty ? <Map<String, dynamic>>[] : await _fleetService.getTrucks();
      final trailers = trailerIds.isEmpty ? <Map<String, dynamic>>[] : await _fleetService.getTrailers();

      final grouped = <String, Map<String, dynamic>>{};
      for (final m in maintenances) {
        final vType = m['vehicle_type']?.toString() ?? '';
        final vId = m['vehicle_id'] as int?;
        if (vType.isEmpty || vId == null) continue;
        final key = '$vType:$vId';
        if (!grouped.containsKey(key)) {
          grouped[key] = {
            'vehicle_type': vType,
            'vehicle_id': vId,
            'records': <Map<String, dynamic>>[],
            'total': 0.0,
          };
        }
        final entry = grouped[key]!;
        final records = entry['records'] as List<Map<String, dynamic>>;
        records.add(m);
        entry['total'] = (entry['total'] as double) + ((m['amount'] as num?)?.toDouble() ?? 0.0);
      }

      final enriched = <Map<String, dynamic>>[];
      for (final entry in grouped.values) {
        final vType = entry['vehicle_type'] as String;
        final vId = entry['vehicle_id'] as int;
        Map<String, dynamic>? vehicle;
        if (vType == 'truck') {
          vehicle = trucks.firstWhere((t) => t['id'] == vId, orElse: () => <String, dynamic>{});
        } else {
          vehicle = trailers.firstWhere((t) => t['id'] == vId, orElse: () => <String, dynamic>{});
        }
        enriched.add({
          'vehicle': vehicle,
          'vehicle_type': vType,
          'vehicle_id': vId,
          'records': entry['records'],
          'total': entry['total'],
        });
      }
      enriched.sort((a, b) {
        final labelA = ((a['vehicle'] as Map<String, dynamic>)['plate']?.toString() ??
                (a['vehicle'] as Map<String, dynamic>)['plate_number']?.toString() ??
                '')
            .toLowerCase();
        final labelB = ((b['vehicle'] as Map<String, dynamic>)['plate']?.toString() ??
                (b['vehicle'] as Map<String, dynamic>)['plate_number']?.toString() ??
                '')
            .toLowerCase();
        return labelA.compareTo(labelB);
      });

      if (!mounted) return;
      setState(() {
        _vehicles = enriched;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading expense category detail: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalAll = _vehicles.fold<double>(0, (sum, v) => sum + (v['total'] as double));
    final totalRecords = _vehicles.fold<int>(0, (sum, v) => sum + ((v['records'] as List).length));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseType),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Center(child: Text('لا توجد مصاريف من هذا النوع', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStat('المركبات', '${_vehicles.length}'),
                            _buildStat('السجلات', '$totalRecords'),
                            _buildStat('الإجمالي', '${totalAll.toStringAsFixed(2)} DH'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _vehicles.length,
                        itemBuilder: (context, index) {
                          final entry = _vehicles[index];
                          final vehicle = entry['vehicle'] as Map<String, dynamic>;
                          final vType = entry['vehicle_type'] as String;
                          final vId = entry['vehicle_id'] as int;
                          final records = entry['records'] as List<Map<String, dynamic>>;
                          final total = entry['total'] as double;
                          final plate = vehicle['plate']?.toString() ??
                              vehicle['plate_number']?.toString() ??
                              (vType == 'truck' ? 'شاحنة' : 'مقطورة');
                          final icon = vType == 'truck' ? Icons.local_shipping_rounded : Icons.share_rounded;
                          final iconColor = vType == 'truck' ? Colors.blue[700] : Colors.teal[700];
                          final vLabel = vType == 'truck' ? 'شاحنة' : 'مقطورة';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VehicleExpenseScreen(
                                      isAdmin: true,
                                      vehicleType: vType,
                                      vehicleId: vId,
                                      expenseType: widget.expenseType,
                                    ),
                                  ),
                                );
                              },
                              child: ListTile(
                                leading: Icon(icon, color: iconColor),
                                title: Text('$vLabel: $plate', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${records.length} سجل • ${total.toStringAsFixed(2)} DH'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('${records.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_left_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
