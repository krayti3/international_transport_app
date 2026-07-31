import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../widgets/date_wheel_picker.dart';
import '../services/fleet_service.dart';
import '../services/maintenance_service.dart';
import '../models/maintenance_schedule.dart';

// ignore_for_file: use_build_context_synchronously

class MaintenanceScheduleScreen extends StatefulWidget {
  const MaintenanceScheduleScreen({super.key, required this.isAdmin, this.vehicleId, this.vehicleType});
  final bool isAdmin;
  final int? vehicleId;
  final String? vehicleType;

  @override
  State<MaintenanceScheduleScreen> createState() => _MaintenanceScheduleScreenState();
}

class _MaintenanceScheduleScreenState extends State<MaintenanceScheduleScreen> {
  final FleetService _fleetService = FleetService();
  final MaintenanceService _maintenanceService = MaintenanceService();
  List<Map<String, dynamic>> _vehicles = [];
  List<MaintenanceSchedule> _schedules = [];
  bool _isLoading = true;
  String? _filterStatus;
  String? _filterVehicleType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final trucks = await _fleetService.getTrucks();
    final trailers = await _fleetService.getTrailers();
    final schedules = await _maintenanceService.getMaintenanceSchedules(
      vehicleType: widget.vehicleType ?? _filterVehicleType,
      vehicleId: widget.vehicleId,
      status: _filterStatus,
    );
    if (mounted) {
      setState(() {
        _vehicles = [
          ...trucks.map((t) => {'id': t['id'], 'plate': t['plate'] ?? t['plate_number'], 'type': 'truck', 'model': t['model']}),
          ...trailers.map((t) => {'id': t['id'], 'plate': t['plate'] ?? t['plate_number'], 'type': 'trailer', 'model': t['type']}),
        ];
        _schedules = schedules;
        _isLoading = false;
      });
    }
  }

  Future<void> _openScheduleDialog({MaintenanceSchedule? schedule}) async {
    final isEdit = schedule != null;
    String? selectedVehicleType = schedule?.vehicleType ?? widget.vehicleType ?? 'truck';
    int? selectedVehicleId = schedule?.vehicleId ?? widget.vehicleId;
    String taskType = schedule?.taskType ?? '';
    String description = schedule?.description ?? '';
    DateTime scheduledDate = schedule?.scheduledDate ?? DateTime.now();
    double? dueKm = schedule?.dueKm;
    String status = schedule?.status ?? 'pending';
    String? assignedTo = schedule?.assignedTo;
    double? estimatedCost = schedule?.estimatedCost;
    String? notes = schedule?.notes;

    final filteredVehicles = _vehicles.where((v) {
      if (selectedVehicleType == null) return true;
      return v['type']?.toString() == selectedVehicleType;
    }).toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final effectiveVehicles = selectedVehicleType == null ? _vehicles : filteredVehicles;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : null,
            title: Text(isEdit ? 'تعديل موعد صيانة' : 'إضافة موعد صيانة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedVehicleType,
                    decoration: const InputDecoration(labelText: 'نوع المركبة'),
                    items: const [
                      DropdownMenuItem(value: 'truck', child: Text('شاحنة')),
                      DropdownMenuItem(value: 'trailer', child: Text('مقطورة')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          selectedVehicleType = v;
                          selectedVehicleId = null;
                        });
                      }
                    },
                  ),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedVehicleId,
                    decoration: InputDecoration(
                      labelText: selectedVehicleType == 'truck' ? 'الشاحنة' : 'المقطورة',
                    ),
                    items: effectiveVehicles
                        .map((v) => DropdownMenuItem<int?>(
                              value: (v['id'] as num?)?.toInt(),
                              child: Text(
                                '${v['plate']?.toString() ?? ''} — ${v['model']?.toString() ?? ''}',
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedVehicleId = v),
                  ),
                  TextFormField(
                    initialValue: taskType,
                    decoration: const InputDecoration(labelText: 'نوع المهمة (مثال: تغيير زيت، فحص فرامل)'),
                    onChanged: (v) => taskType = v,
                  ),
                  TextFormField(
                    initialValue: description,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                    maxLines: 2,
                    onChanged: (v) => description = v,
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showDateWheelPicker(
                        context: context,
                        initialDate: scheduledDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => scheduledDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'تاريخ الصيانة المجدول'),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(scheduledDate),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ),
                  TextFormField(
                    initialValue: dueKm?.toString(),
                    decoration: const InputDecoration(labelText: 'العداد المستهدف (كم)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => dueKm = double.tryParse(v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                      DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                      DropdownMenuItem(value: 'skipped', child: Text('تم التخطي')),
                      DropdownMenuItem(value: 'overdue', child: Text('متأخر')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => status = v);
                    },
                  ),
                  TextFormField(
                    initialValue: assignedTo,
                    decoration: const InputDecoration(labelText: 'الورشة / الفني'),
                    onChanged: (v) => assignedTo = v,
                  ),
                  TextFormField(
                    initialValue: estimatedCost?.toString(),
                    decoration: const InputDecoration(labelText: 'التكلفة التقديرية (DH)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => estimatedCost = double.tryParse(v),
                  ),
                  TextFormField(
                    initialValue: notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 2,
                    onChanged: (v) => notes = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedVehicleId == null || taskType.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى ملء الحقول المطلوبة')),
                    );
                    return;
                  }
                  final data = {
                    'vehicle_type': selectedVehicleType,
                    'vehicle_id': selectedVehicleId,
                    'task_type': taskType.trim(),
                    'description': description.trim().isEmpty ? null : description.trim(),
                    'scheduled_date': DateFormat('dd/MM/yyyy').format(scheduledDate),
                    'due_km': dueKm,
                    'status': status,
                    'assigned_to': (assignedTo?.trim().isEmpty ?? true) ? null : assignedTo?.trim(),
                    'estimated_cost': estimatedCost,
                    'notes': (notes?.trim().isEmpty ?? true) ? null : notes?.trim(),
                  };
                  try {
                    if (isEdit) {
                      await _fleetService.updateMaintenanceSchedule(schedule.id!, data);
                    } else {
                      await _fleetService.insertMaintenanceSchedule(data);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'تم تحديث موعد الصيانة' : 'تم إضافة موعد الصيانة')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                },
                child: Text(isEdit ? 'تحديث' : 'حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _markCompleted(MaintenanceSchedule schedule) async {
    try {
      await _maintenanceService.completeMaintenanceSchedule(
        schedule.id!,
        completedKm: schedule.dueKm,
        notes: schedule.notes,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديد الصيانة كمكتملة')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _deleteSchedule(MaintenanceSchedule schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف موعد الصيانة'),
        content: const Text('هل أنت متأكد من الحذف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _maintenanceService.deleteMaintenanceSchedule(schedule.id!);
      await _loadData();
    }
  }

  String _getVehicleLabel(MaintenanceSchedule schedule) {
    final vehicle = _vehicles.firstWhere(
      (v) => (v['id'] as num?)?.toInt() == schedule.vehicleId && v['type']?.toString() == schedule.vehicleType,
      orElse: () => {'plate': 'غير معروف'},
    );
    return vehicle['plate']?.toString() ?? 'غير معروف';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'skipped':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'مكتمل';
      case 'overdue':
        return 'متأخر';
      case 'skipped':
        return 'تم التخطي';
      default:
        return 'قيد الانتظار';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _schedules;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicleId != null ? 'صيانة ${_getVehicleLabel(_schedules.isNotEmpty ? _schedules.first : MaintenanceSchedule(vehicleType: widget.vehicleType ?? 'truck', vehicleId: widget.vehicleId ?? 0, taskType: '', scheduledDate: DateTime.now()))}' : 'جدول الصيانة الدورية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded),
            onPressed: () async {
              await _maintenanceService.sendMaintenanceNotifications();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال التذكيرات للصيانة القادمة')),
                );
              }
            },
            tooltip: 'إرسال تذكيرات',
          ),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _openScheduleDialog(),
              tooltip: 'إضافة موعد صيانة',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('فلترة المواعيد', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: _filterVehicleType ?? widget.vehicleType,
                                decoration: const InputDecoration(labelText: 'نوع المركبة'),
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('الكل')),
                                  DropdownMenuItem(value: 'truck', child: Text('شاحنة')),
                                  DropdownMenuItem(value: 'trailer', child: Text('مقطورة')),
                                ],
                                onChanged: (v) {
                                  setState(() => _filterVehicleType = v);
                                  _loadData();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: _filterStatus,
                                decoration: const InputDecoration(labelText: 'الحالة'),
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('الكل')),
                                  DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                                  DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                                  DropdownMenuItem(value: 'overdue', child: Text('متأخر')),
                                ],
                                onChanged: (v) {
                                  setState(() => _filterStatus = v);
                                  _loadData();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: filtered.isEmpty
                        ? const Center(child: Text('لا توجد مواعيد صيانة'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final schedule = filtered[index];
                              final isOverdue = schedule.status == 'overdue';
                              final isPending = schedule.status == 'pending';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: isOverdue
                                    ? Colors.red.withValues(alpha: 0.08)
                                    : (isDark ? const Color(0xFF1E1E1E) : null),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.build_rounded,
                                    color: _statusColor(schedule.status),
                                  ),
                                  title: Text(schedule.taskType),
                                  subtitle: Text(
                                    '${_getVehicleLabel(schedule)} • ${DateFormat('yyyy/MM/dd').format(schedule.scheduledDate)}${schedule.assignedTo != null ? ' • ${schedule.assignedTo}' : ''}${schedule.estimatedCost != null ? ' • ${schedule.estimatedCost!.toStringAsFixed(2)} DH' : ''}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _statusColor(schedule.status).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _statusColor(schedule.status)),
                                        ),
                                        child: Text(
                                          _statusLabel(schedule.status),
                                          style: TextStyle(color: _statusColor(schedule.status), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (widget.isAdmin) ...[
                                        const SizedBox(width: 4),
                                        if (isPending || isOverdue)
                                          IconButton(
                                            icon: const Icon(Icons.check_rounded, color: Colors.green, size: 20),
                                            onPressed: () => _markCompleted(schedule),
                                            tooltip: 'إكمال',
                                          ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'edit') {
                                              await _openScheduleDialog(schedule: schedule);
                                            } else if (value == 'delete') {
                                              await _deleteSchedule(schedule);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                            PopupMenuItem(value: 'delete', child: Text('حذف')),
                                          ],
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
