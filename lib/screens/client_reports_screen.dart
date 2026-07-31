import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import '../services/fleet_service.dart';
import '../services/advance_service.dart';
import '../services/pdf_service.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/summary_card.dart';

// ignore_for_file: use_build_context_synchronously

class ClientReportsScreen extends StatefulWidget {
  const ClientReportsScreen({super.key});

  @override
  State<ClientReportsScreen> createState() => _ClientReportsScreenState();
}

class _ClientReportsScreenState extends State<ClientReportsScreen> {
  final ClientService _clientService = ClientService();
  final FleetService _fleetService = FleetService();
  final AdvanceService _advanceService = AdvanceService();
  final _formKey = GlobalKey<FormState>();

  List<Client> _clients = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _trucks = [];

  int? _selectedClientId;
  List<Map<String, dynamic>> _clientTrips = [];
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;

  bool _isLoading = true;
  bool _isLoadingTrips = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    final clients = await _clientService.getClients();
    final drivers = await _fleetService.getDrivers();
    final trucks = await _fleetService.getTrucks();

    if (mounted) {
      setState(() {
        _clients = clients;
        _drivers = drivers;
        _trucks = trucks;
        _isLoading = false;
      });
    }
  }

  Future<void> _onClientSelected(int? clientId) async {
    if (clientId == null) {
      setState(() {
        _selectedClientId = null;
        _clientTrips = [];
        _totalRevenue = 0.0;
        _totalExpenses = 0.0;
      });
      return;
    }

    setState(() => _isLoadingTrips = true);

    try {
      final trips = await _advanceService.getTripOrdersByClient(clientId);
      final tripIds = trips
          .map((t) => t['trip_id'] as int?)
          .whereType<int>()
          .toSet()
          .toList();

      final advances = await _advanceService.getAdvancesByIds(tripIds);
      final advanceMap = {for (var a in advances) a['id'] as int: a};

      final merged = trips.map((trip) {
        final advance = advanceMap[trip['trip_id'] as int?];
        return {
          ...trip,
          'advance': advance,
        };
      }).toList();

      merged.sort((a, b) {
        final dateA = a['departure_date']?.toString() ?? '';
        final dateB = b['departure_date']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });

      double revenue = 0.0;
      double expenses = 0.0;

      final enriched = merged.map((trip) {
        final price = (trip['price'] as num?)?.toDouble() ?? 0.0;
        final expense = (trip['specific_expenses'] as num?)?.toDouble() ?? 0.0;
        revenue += price;
        expenses += expense;

        final advance = trip['advance'] as Map<String, dynamic>?;
        final driverId = advance?['driver_id'];
        final truckId = advance?['truck_id'];
        final driver = driverId != null
            ? _drivers.firstWhere((d) => d['id'] == driverId,
                orElse: () => {'name': 'غير معروف'})
            : null;
        final truck = truckId != null
            ? _trucks.firstWhere((t) => t['id'] == truckId,
                orElse: () => {'plate': 'غير معروف', 'plate_number': 'غير معروف'})
            : null;

        return {
          ...trip,
          'date': advance?['date_out']?.toString() ??
              trip['departure_date']?.toString() ??
              '',
          'status': advance?['status']?.toString() ??
              trip['status']?.toString() ??
              '',
          'driver_name': driver?['name']?.toString() ?? 'غير معروف',
          'truck_plate': truck?['plate']?.toString() ??
              truck?['plate_number']?.toString() ??
              'غير معروف',
        };
      }).toList();

      setState(() {
        _selectedClientId = clientId;
        _clientTrips = enriched;
        _totalRevenue = revenue;
        _totalExpenses = expenses;
        _isLoadingTrips = false;
      });
    } catch (e) {
      setState(() => _isLoadingTrips = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_selectedClientId == null || _clientTrips.isEmpty) return;

    final client = _clients.firstWhere(
      (c) => c.id == _selectedClientId,
      orElse: () => throw StateError('Client not found'),
    );

    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري إنشاء التقرير...'),
          ],
        ),
      ),
    );

    try {
      await PdfService.instance.previewClientReport(
        client: client.toMap(),
        trips: _clientTrips,
        totalRevenue: _totalRevenue,
        totalExpenses: _totalExpenses,
        currency: client.currency,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء التقرير: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقارير الزبائن')),
      floatingActionButton: _selectedClientId != null && !_isLoadingTrips && _clientTrips.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isExporting ? null : _exportPdf,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isExporting
                  ? 'جاري التصدير...'
                  : 'تصدير التقرير PDF'),
              backgroundColor: Colors.redAccent,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? const Center(child: Text('لا يوجد زبائن حالياً'))
              : CallbackShortcuts(
                  bindings: {
                    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
                        () => _exportPdf(),
                  },
                  child: RefreshIndicator(
                    onRefresh: _loadReferenceData,
                    child: AppConstrained(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'اختر الزبون',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_search),
                              ),
                              items: _clients
                                  .toList()
                                   .sorted((a, b) => a.name.compareTo(b.name))
                                  .map((c) {
                                    return DropdownMenuItem<int>(
                                      value: c.id,
                                      child: Text(c.name),
                                    );
                                  }).toList(),
                              onChanged: (v) => _onClientSelected(v),
                              validator: (v) =>
                                  v == null ? 'يرجى اختيار زبون' : null,
                            ),
                            const SizedBox(height: 16),
                            if (_selectedClientId != null) ...[
                              if (_isLoadingTrips)
                                const Expanded(
                                    child: Center(child: CircularProgressIndicator()))
                              else if (_clientTrips.isEmpty)
                                const Expanded(
                                  child: Center(
                                    child: Text('لا توجد رحلات لهذا الزبون'),
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.only(bottom: 80),
                                    children: [
                                      _buildSummaryRow(),
                                      const SizedBox(height: 16),
                                      ..._clientTrips.map((trip) => _buildTripCard(trip)),
                                    ],
                                  ),
                                ),
                              ],
                            ] else
                              const Expanded(
                                child: Center(
                                  child: Text(
                                    'يرجى اختيار زبون لعرض التقرير',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryRow() {
    final net = _totalRevenue - _totalExpenses;
    return Row(
      children: [
        Expanded(
          child: SummaryCard(
            title: 'إجمالي الإيرادات',
            value: '${_totalRevenue.toStringAsFixed(2)} د.أ',
            color: Colors.green,
            isLarge: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryCard(
            title: 'إجمالي المصاريف',
            value: '${_totalExpenses.toStringAsFixed(2)} د.أ',
            color: Colors.red,
            isLarge: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryCard(
            title: 'الصافي',
            value: '${net.toStringAsFixed(2)} د.أ',
            color: net >= 0 ? Colors.blue : Colors.orange,
            isLarge: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final direction = trip['direction']?.toString() ?? '';
    final isReturn = direction == 'return';
    final route = trip['route']?.toString() ?? '';
    final date = trip['date']?.toString() ?? '';
    final driverName = trip['driver_name']?.toString() ?? '';
    final truckPlate = trip['truck_plate']?.toString() ?? '';
    final price = (trip['price'] as num?)?.toDouble() ?? 0.0;
    final expenses = (trip['specific_expenses'] as num?)?.toDouble() ?? 0.0;
    final status = trip['status']?.toString() ?? '';

    Color statusColor = Colors.grey;
    switch (status) {
      case 'en_route':
        statusColor = Colors.blue;
        break;
      case 'settled':
        statusColor = Colors.green;
        break;
      case 'scheduled':
        statusColor = Colors.orange;
        break;
      case 'pending':
        statusColor = Colors.grey;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(
                    isReturn ? 'عودة' : 'ذهاب',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: isReturn ? Colors.teal : Colors.indigo,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(route, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('التاريخ: $date', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('السائق: $driverName  |  الشاحنة: $truckPlate',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAmountChip(
                    'السعر',
                    '${price.toStringAsFixed(2)} د.أ',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAmountChip(
                    'مصاريف',
                    '${expenses.toStringAsFixed(2)} د.أ',
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color)),
        ],
      ),
    );
  }
}
