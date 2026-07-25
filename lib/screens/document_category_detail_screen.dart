import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/supabase_service.dart';
import 'vehicle_doc_type_screen.dart';

class DocumentCategoryDetailScreen extends StatefulWidget {
  final String docType;
  const DocumentCategoryDetailScreen({super.key, required this.docType});

  @override
  State<DocumentCategoryDetailScreen> createState() => _DocumentCategoryDetailScreenState();
}

class _DocumentCategoryDetailScreenState extends State<DocumentCategoryDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final responseDocs = await _supabaseService.getDocumentsByDocType(widget.docType);
      if (!mounted) return;

      final vehicleMap = <String, Map<String, dynamic>>{};
      final truckIds = <int>{};
      final trailerIds = <int>{};

      for (final doc in responseDocs) {
        final eType = doc['entity_type']?.toString() ?? '';
        final eId = doc['entity_id'] as int?;
        if (eType.isEmpty || eId == null) continue;
        final key = '$eType:$eId';
        if (!vehicleMap.containsKey(key)) {
          vehicleMap[key] = {
            'entity_type': eType,
            'entity_id': eId,
            'doc': doc,
          };
          if (eType == 'truck') truckIds.add(eId);
          if (eType == 'trailer') trailerIds.add(eId);
        }
      }

      final trucks = truckIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await _supabaseService.getTrucks();
      final trailers = trailerIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await _supabaseService.getTrailers();

      final enriched = <Map<String, dynamic>>[];
      for (final entry in vehicleMap.values) {
        final eType = entry['entity_type'] as String;
        final eId = entry['entity_id'] as int;
        final doc = entry['doc'] as Map<String, dynamic>;
        Map<String, dynamic>? vehicle;
        if (eType == 'truck') {
          vehicle = trucks.firstWhere(
            (t) => t['id'] == eId,
            orElse: () => <String, dynamic>{},
          );
        } else if (eType == 'trailer') {
          vehicle = trailers.firstWhere(
            (t) => t['id'] == eId,
            orElse: () => <String, dynamic>{},
          );
        }
        enriched.add({
          'doc': doc,
          'vehicle': vehicle,
          'entity_type': eType,
          'entity_id': eId,
        });
      }

      if (!mounted) return;
      setState(() {
        _vehicles = enriched;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading category detail: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVehicles {
    final now = DateTime.now();
    return _vehicles.where((entry) {
      final doc = entry['doc'] as Map<String, dynamic>;
      if (_filter == null) return true;
      final expiryStr = doc['expiry_date']?.toString();
      if (expiryStr == null || expiryStr.isEmpty) return _filter == 'expired';
      final expiryDate = DateTime.tryParse(expiryStr);
      if (expiryDate == null) return _filter == 'expired';
      final diff = expiryDate.difference(now).inDays;
      if (_filter == 'expired') return diff < 0;
      if (_filter == 'expiring_soon') return diff >= 0 && diff <= 15;
      if (_filter == 'valid') return diff > 15;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expiredCount = _filteredVehicles.where((entry) {
      final doc = entry['doc'] as Map<String, dynamic>;
      final expiryStr = doc['expiry_date']?.toString();
      final expiryDate = expiryStr != null && expiryStr.isNotEmpty ? DateTime.tryParse(expiryStr) : null;
      if (expiryDate == null) return false;
      return expiryDate.difference(DateTime.now()).inDays < 0;
    }).length;
    final expiringCount = _filteredVehicles.where((entry) {
      final doc = entry['doc'] as Map<String, dynamic>;
      final expiryStr = doc['expiry_date']?.toString();
      final expiryDate = expiryStr != null && expiryStr.isNotEmpty ? DateTime.tryParse(expiryStr) : null;
      if (expiryDate == null) return false;
      final diff = expiryDate.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 15;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docType),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                  child: Row(
                    children: [
                      _SummaryBadge(label: 'الكل', value: _filteredVehicles.length, isActive: _filter == null, isDark: isDark),
                      const SizedBox(width: 8),
                      _SummaryBadge(label: 'منتهية', value: expiredCount, isActive: _filter == 'expired', isDark: isDark, color: Colors.red),
                      const SizedBox(width: 8),
                      _SummaryBadge(label: 'قريبة الانتهاء', value: expiringCount, isActive: _filter == 'expiring_soon', isDark: isDark, color: Colors.orange),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      ChoiceChip(label: const Text('الكل'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('منتهية'), selected: _filter == 'expired', onSelected: (_) => setState(() => _filter = 'expired')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('تنتهي خلال 15 يوم'), selected: _filter == 'expiring_soon', onSelected: (_) => setState(() => _filter = 'expiring_soon')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('صالحة'), selected: _filter == 'valid', onSelected: (_) => setState(() => _filter = 'valid')),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredVehicles.isEmpty
                      ? Center(child: Text('لا توجد وثائق', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredVehicles.length,
                          itemBuilder: (context, index) {
                            final entry = _filteredVehicles[index];
                            final doc = entry['doc'] as Map<String, dynamic>;
                            final vehicle = entry['vehicle'] as Map<String, dynamic>?;
                            final entityType = entry['entity_type'] as String;
                            final eId = entry['entity_id'] as int;
                            String plate;
                            if (vehicle != null && vehicle.isNotEmpty) {
                              plate = vehicle['plate']?.toString() ?? vehicle['plate_number']?.toString() ?? 'غير معروف';
                            } else {
                              plate = 'مركبة غير معروفة';
                            }
                            final vehicleLabel = entityType == 'truck' ? 'شاحنة' : 'مقطورة';
                            final expiryStr = doc['expiry_date']?.toString();
                            final expiryDate = expiryStr != null && expiryStr.isNotEmpty ? DateTime.tryParse(expiryStr) : null;
                            final formattedDate = expiryDate != null ? DateFormat('dd/MM/yyyy').format(expiryDate) : 'غير معروف';
                            final docNumber = doc['document_number']?.toString() ?? '—';
                            final diff = expiryDate?.difference(DateTime.now()).inDays;
                            Color statusColor = Colors.green;
                            String statusText = 'صالحة';
                            if (diff == null) {
                              statusColor = Colors.grey;
                              statusText = 'غير معروف';
                            } else if (diff < 0) {
                              statusColor = Colors.red;
                              statusText = 'منتهية منذ ${diff.abs()} يوم';
                            } else if (diff == 0) {
                              statusColor = Colors.deepOrange;
                              statusText = 'تنتهي اليوم';
                            } else if (diff <= 15) {
                              statusColor = Colors.orange;
                              statusText = 'متبقي $diff يوم';
                            } else {
                              statusText = 'متبقي $diff يوم';
                            }

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
                                      builder: (_) => VehicleDocTypeScreen(
                                        isAdmin: true,
                                        entityType: entityType,
                                        entityId: eId,
                                        docType: widget.docType,
                                      ),
                                    ),
                                  );
                                },
                                child: ListTile(
                                  leading: Icon(
                                    entityType == 'truck' ? Icons.local_shipping_rounded : Icons.share_rounded,
                                    color: entityType == 'truck' ? Colors.blue[700] : Colors.teal[700],
                                  ),
                                  title: Text('$vehicleLabel: $plate', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('رقم الوثيقة: $docNumber'),
                                      Text('تاريخ الانتهاء: $formattedDate', textDirection: TextDirection.ltr),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(statusText, style: TextStyle(fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
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
                ),
              ],
            ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final int value;
  final bool isActive;
  final bool isDark;
  final Color? color;

  const _SummaryBadge({required this.label, required this.value, required this.isActive, required this.isDark, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? (color ?? Theme.of(context).colorScheme.primary)
        : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[200]!);
    final textColor = isActive ? Colors.white : (isDark ? Colors.grey[300]! : Colors.grey[700]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}
