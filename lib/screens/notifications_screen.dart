import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  static const _invoiceColor = Colors.blue;
  static const _documentColor = Colors.orange;
  static const _maintenanceColor = Colors.red;
  static const _visaColor = Colors.purple;
  static const _oilChangeColor = Colors.amber;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = <Map<String, dynamic>>[];

    final invoices = await _supabaseService.getUpcomingInvoices();
    final docs = await _supabaseService.getUpcomingDocumentExpiries();
    final maintenances = await _supabaseService.getUpcomingMaintenanceDueDates();
    final visas = await _supabaseService.getUpcomingVisaExpiries();
    final oilChanges = await _supabaseService.getOilChangeAlerts();

    for (final inv in invoices) {
      events.add({
        'date': DateTime.tryParse(inv['due_date']?.toString() ?? ''),
        'type': 'invoice',
        'title': 'فاتورة ${inv['invoice_number'] ?? ''}',
        'subtitle': inv['client']?['name']?.toString() ?? '',
        'amount': inv['total_amount']?.toString() ?? '0',
        'color': _invoiceColor,
        'icon': Icons.receipt_rounded,
      });
    }

    for (final doc in docs) {
      final entityType = doc['entity_type']?.toString() ?? doc['source']?.toString() ?? '';
      final plate = (entityType == 'truck'
              ? (doc['truck']?['plate'] ?? doc['truck']?['plate_number'])
              : doc['entity']?['plate_number'])
          ?.toString() ??
          doc['plate']?.toString() ??
          '';
      events.add({
        'date': DateTime.tryParse(doc['expiry_date']?.toString() ?? ''),
        'type': 'document',
        'title': 'انتهاء صلاحية وثيقة ${doc['document_number'] ?? doc['doc_type'] ?? ''}',
        'subtitle': '${entityType == 'truck' ? 'شاحنة' : 'مقطورة'} $plate',
        'color': _documentColor,
        'icon': Icons.description_rounded,
      });
    }

    for (final m in maintenances) {
      events.add({
        'date': DateTime.tryParse(m['due_date']?.toString() ?? ''),
        'type': 'maintenance',
        'title': '${m['expense_type'] ?? 'صيانة'} - ${m['truck_plate'] ?? m['truck']?['plate'] ?? ''}',
        'subtitle': m['description']?.toString() ?? '',
        'color': _maintenanceColor,
        'icon': Icons.build_rounded,
      });
    }

    for (final d in visas) {
      events.add({
        'date': DateTime.tryParse(d['visa_expiry_date']?.toString() ?? ''),
        'type': 'visa',
        'title': 'انتهاء تأشيرة ${d['name'] ?? ''}',
        'subtitle': d['nationality']?.toString() ?? '',
        'color': _visaColor,
        'icon': Icons.card_travel_rounded,
      });
    }

    for (final t in oilChanges) {
      final currentKm = (t['current_km'] as num?)?.toDouble();
      events.add({
        'date': DateTime.now(),
        'type': 'oil_change',
        'title': 'تغيير الزيت - ${t['plate'] ?? t['plate_number'] ?? ''}',
        'subtitle': 'العداد: ${currentKm?.toStringAsFixed(0) ?? '0'} كم',
        'color': _oilChangeColor,
        'icon': Icons.oil_barrel_rounded,
      });
    }

    events.removeWhere((e) => e['date'] == null);

    events.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> events) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final event in events) {
      final date = event['date'] as DateTime;
      final dateKey = DateTime(date.year, date.month, date.day);
      map.putIfAbsent(dateKey, () => []).add(event);
    }
    return map;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return 'اليوم';
    if (eventDate == tomorrow) return 'غداً';

    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grouped = _groupByDate(_events);
    final sortedDates = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التنبيهات والمواعيد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : sortedDates.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد مواعيد قادمة',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final events = grouped[date]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getDateHeaderColor(date, isDark),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getDateIcon(date),
                                size: 20,
                                color: _getDateIconColor(date),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(date),
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getDateTextColor(date, isDark),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getEventCountColor(date, events.length),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${events.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...events.map((event) => _buildEventCard(event, isDark)),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, bool isDark) {
    final date = event['date'] as DateTime;
    final type = event['type'] as String;
    final title = event['title']?.toString() ?? '';
    final subtitle = event['subtitle']?.toString() ?? '';
    final color = event['color'] as Color? ?? Colors.grey;
    final icon = event['icon'] as IconData? ?? Icons.event_rounded;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDark ? const Color(0xFF1E1E1E) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) Text(subtitle),
            Text(
              DateFormat('HH:mm').format(date),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getTypeLabel(type),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _getDateHeaderColor(DateTime date, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50;
    if (eventDate.isBefore(today)) return isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50;
    return isDark ? Colors.blueGrey.shade800 : Colors.blue.shade50;
  }

  Color _getDateTextColor(DateTime date, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return Colors.green;
    if (eventDate.isBefore(today)) return Colors.red;
    return isDark ? Colors.white : Colors.black87;
  }

  IconData _getDateIcon(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return Icons.today_rounded;
    if (eventDate.isBefore(today)) return Icons.warning_amber_rounded;
    return Icons.calendar_today_rounded;
  }

  Color _getDateIconColor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return Colors.green;
    if (eventDate.isBefore(today)) return Colors.red;
    return Colors.blue;
  }

  Color _getEventCountColor(DateTime date, int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return Colors.green;
    if (eventDate.isBefore(today)) return Colors.red;
    return Colors.blue;
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'invoice':
        return 'فاتورة';
      case 'document':
        return 'وثيقة';
      case 'maintenance':
        return 'صيانة';
      case 'visa':
        return 'تأشيرة';
      case 'oil_change':
        return 'زيت';
      default:
        return type;
    }
  }
}
