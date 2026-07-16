import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';

// ignore_for_file: use_build_context_synchronously

class FleetAlertsScreen extends StatefulWidget {
  const FleetAlertsScreen({super.key});

  @override
  State<FleetAlertsScreen> createState() => _FleetAlertsScreenState();
}

class _FleetAlertsScreenState extends State<FleetAlertsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _trailers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final docs = await _supabaseService.getDocuments();
    final trucks = await _supabaseService.getTrucks();
    final trailers = await _supabaseService.getTrailers();
    if (mounted) {
      setState(() {
        _documents = docs;
        _trucks = trucks;
        _trailers = trailers;
        _isLoading = false;
      });
    }
  }

  String _vehicleLabel(String type, int id) {
    if (type == 'trailer') {
      final t = _trailers.where((e) => e['id'] == id).firstOrNull;
      return 'مقطورة: ${t?['plate_number']?.toString() ?? id}';
    }
    final t = _trucks.where((e) => e['id'] == id).firstOrNull;
    return 'شاحنة: ${t?['plate']?.toString() ?? t?['plate_number']?.toString() ?? id}';
  }

  /// Days remaining until a document expires (negative = expired).
  int _daysLeft(Map<String, dynamic> doc) {
    final expiry = doc['expiry_date']?.toString();
    if (expiry == null) return 9999;
    final dt = DateTime.tryParse(expiry);
    if (dt == null) return 9999;
    return dt.difference(DateTime.now()).inDays;
  }

  List<Widget> _documentAlerts() {
    const window = 30; // تنبيه خلال 30 يوماً القادمة أو المنتهية
    final items = <Widget>[];
    for (final doc in _documents) {
      final daysLeft = _daysLeft(doc);
      if (daysLeft > window) continue; // لا يستدعي تنبيهاً بعد
      final expired = daysLeft <= 0;
      final color = expired ? Colors.red : Colors.orange;
      items.add(Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: Icon(Icons.description, color: color),
          title: Text(doc['document_name']?.toString() ?? 'مستند'),
          subtitle: Text(
            '${_vehicleLabel(doc['vehicle_type']?.toString() ?? 'truck', (doc['vehicle_id'] as num?)?.toInt() ?? 0)}\n'
            'تاريخ الانتهاء: ${doc['expiry_date']}',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Text(
              expired ? 'منتهي' : 'متبقٍ $daysLeft يوم',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ));
    }
    return items;
  }

  List<Widget> _oilAlerts() {
    final items = <Widget>[];
    for (final truck in _trucks) {
      final oilKm = (truck['oil_change_km'] as num?)?.toDouble();
      final currentKm = (truck['current_km'] as num?)?.toDouble() ?? 0.0;
      if (oilKm == null || oilKm <= 0) continue;
      final overdue = currentKm >= oilKm;
      final near = !overdue && (oilKm - currentKm) <= 1000;
      if (!overdue && !near) continue;
      final color = overdue ? Colors.red : Colors.orange;
      items.add(Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: Icon(Icons.oil_barrel, color: color),
          title: Text('تغيير الزيت — ${truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? ''}'),
          subtitle: Text(
            'العداد الحالي: ${currentKm.toStringAsFixed(0)} كم\n'
            'موعد تغيير الزيت عند: ${oilKm.toStringAsFixed(0)} كم',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Text(
              overdue ? 'تجاوز الموعد' : 'اقترب الموعد',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final docAlerts = _documentAlerts();
    final oilAlerts = _oilAlerts();

    return Scaffold(
      appBar: AppBar(title: const Text('تنبيهات الأسطول')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: AppConstrained(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text('مستندات الأوراق والأذون',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (docAlerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('لا توجد تنبيهات مستندات حالياً'),
                      )
                    else
                      ...docAlerts,
                    const SizedBox(height: 24),
                    const Text('تنبيهات تغيير الزيت',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (oilAlerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('لا توجد تنبيهات زيت حالياً'),
                      )
                    else
                      ...oilAlerts,
                    if (docAlerts.isEmpty && oilAlerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(
                          child: Text('✅ لا توجد تنبيهات عاجلة في الأسطول',
                              style: TextStyle(color: Colors.green, fontSize: 16)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
