import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class VisaTrackingScreen extends StatefulWidget {
  const VisaTrackingScreen({super.key});

  @override
  State<VisaTrackingScreen> createState() => _VisaTrackingScreenState();
}

class _VisaTrackingScreenState extends State<VisaTrackingScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    final drivers = await _supabaseService.getDrivers();
    if (!mounted) return;
    setState(() {
      _drivers = drivers;
      _isLoading = false;
    });
  }

  Color _getCardColor(DateTime? expiryDate, bool isDark) {
    if (expiryDate == null) return isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200;
    final now = DateTime.now();
    final diff = expiryDate.difference(now).inDays;
    if (diff < 0) return isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50;
    if (diff <= 30) return isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50;
    return isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50;
  }

  Color _getBorderColor(DateTime? expiryDate) {
    if (expiryDate == null) return Colors.grey;
    final now = DateTime.now();
    final diff = expiryDate.difference(now).inDays;
    if (diff < 0) return Colors.red;
    if (diff <= 30) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(DateTime? expiryDate) {
    if (expiryDate == null) return 'لا توجد بيانات فيزا';
    final now = DateTime.now();
    final diff = expiryDate.difference(now).inDays;
    if (diff < 0) return 'انتهت الصلاحية منذ ${diff.abs()} يوم';
    if (diff == 0) return 'تنتهي اليوم';
    return 'متبقي $diff يوم';
  }

  Future<void> _openVisaDialog({Map<String, dynamic>? driver}) async {
    final isEdit = driver != null;
    final visaNumberController = TextEditingController(text: driver?['visa_number']?.toString() ?? '');
    DateTime? expiryDate = driver != null && driver['visa_expiry_date'] != null
        ? DateTime.tryParse(driver['visa_expiry_date'].toString())
        : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تحديث الفيزا' : 'إضافة فيزا'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('السائق: ${driver?['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: visaNumberController,
                  decoration: const InputDecoration(labelText: 'رقم الفيزا'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => expiryDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ انتهاء الفيزا'),
                    child: Text(
                      expiryDate == null
                          ? 'اختر التاريخ'
                          : DateFormat('yyyy/MM/dd').format(expiryDate!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final visaNumber = visaNumberController.text.trim();
                if (visaNumber.isEmpty || expiryDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول')),
                  );
                  return;
                }
                try {
                  await _supabaseService.updateDriverVisa(
                    driver!['id'].toString(),
                    visaNumber,
                    expiryDate!,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث الفيزا بنجاح')),
                  );
                  await _loadDrivers();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e')),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع صلاحية الفيزا'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadDrivers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drivers.isEmpty
              ? Center(
                  child: Text(
                    'لا يوجد سائقين',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _drivers.length,
                  itemBuilder: (context, index) {
                    final driver = _drivers[index];
                    final expiryStr = driver['visa_expiry_date']?.toString();
                    final expiryDate = expiryStr != null && expiryStr.isNotEmpty
                        ? DateTime.tryParse(expiryStr)
                        : null;
                    final cardColor = _getCardColor(expiryDate, isDark);
                    final borderColor = _getBorderColor(expiryDate);
                    final statusText = _getStatusText(expiryDate);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: borderColor, width: 1.5),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: borderColor.withValues(alpha: 0.2),
                          child: Icon(Icons.person, color: borderColor),
                        ),
                        title: Text(
                          driver['name']?.toString() ?? 'بدون اسم',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('رقم الفيزا: ${driver['visa_number']?.toString() ?? 'غير محدد'}'),
                            const SizedBox(height: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: borderColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.edit_calendar_rounded, color: isDark ? Colors.teal[300] : Colors.teal[700]),
                          tooltip: 'تحديث الفيزا',
                          onPressed: () => _openVisaDialog(driver: driver),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}