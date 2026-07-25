import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/models/invoice.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';

// ignore_for_file: use_build_context_synchronously

/// شاشة تذكيرات الفواتير المتأخرة — للسكرتيرة والأدمن.
/// تعرض الفواتير التي تجاوزت تاريخ الاستحقاق وغير المدفوعة، مع زر يفتح
/// واتساب عبر رابط wa.me برسالة تذكير جاهزة موجّهة لرقم الزبون.
class OverdueRemindersScreen extends StatefulWidget {
  const OverdueRemindersScreen({super.key});

  @override
  State<OverdueRemindersScreen> createState() => _OverdueRemindersScreenState();
}

class _OverdueRemindersScreenState extends State<OverdueRemindersScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Invoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final invoices = await _supabaseService.getOverdueInvoices();
    if (!mounted) return;
    setState(() {
      _invoices = invoices;
      _isLoading = false;
    });
  }

  String _invoiceNumber(Invoice inv) =>
      inv.invoiceNumber;

  double _remaining(Invoice inv) {
    final total = inv.totalAmount.toDouble();
    final paid = (inv.paidAmount ?? Decimal.zero).toDouble();
    return (total - paid).clamp(0.0, total);
  }

  int _daysOverdue(Invoice inv) {
    final due = inv.dueDate;
    if (due == null) return 0;
    return DateTime.now().difference(due).inDays;
  }

  String _clientName(Invoice inv) {
    final client = inv.client;
    return client?['name']?.toString() ?? context.tr('بدون اسم');
  }

  String _clientPhone(Invoice inv) {
    final client = inv.client;
    return client?['phone']?.toString() ?? '';
  }

  Future<void> _sendWhatsApp(Invoice inv) async {
    final phone = _clientPhone(inv).replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('لا يوجد رقم هاتف للزبون'))),
      );
      return;
    }
    final name = _clientName(inv);
    final number = _invoiceNumber(inv);
    final amount = _remaining(inv).toStringAsFixed(2);
    final message = context.tr(
        'أهلاً شركة {0}، نود تذكيركم بأن الفاتورة رقم {1} بمبلغ {2} درهم قد تجاوزت تاريخ الاستحقاق. يرجى التسوية في أقرب وقت.',
        [name, number, amount]);
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (!mounted) {
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('تعذّر فتح واتساب'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('خطأ: {0}', [e]))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('تذكيرات الفواتير المتأخرة')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: context.tr('تحديث'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('لا توجد فواتير متأخرة 🎉'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final inv = _invoices[index];
                      final days = _daysOverdue(inv);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _clientName(inv),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'متأخرة منذ $days يوم',
                                      style: const TextStyle(
                                          color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('رقم الفاتورة: ${_invoiceNumber(inv)}'),
                              Text(
                                'المبلغ المتبقي: ${_remaining(inv).toStringAsFixed(2)} درهم',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                               Text('تاريخ الاستحقاق: ${inv.dueDate != null ? DateFormat('dd/MM/yyyy').format(inv.dueDate!) : ''}', textDirection: TextDirection.ltr),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _sendWhatsApp(inv),
                                  icon: const Icon(Icons.message),
                                  label: const Text('إرسال تذكير عبر الواتساب'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
