import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';

// ignore_for_file: use_build_context_synchronously

class ClientDetailsScreen extends StatefulWidget {
  const ClientDetailsScreen({
    super.key,
    required this.client,
    required this.onDeleted,
    required this.onUpdated,
  });

  final Map<String, dynamic> client;
  final VoidCallback onDeleted;
  final VoidCallback onUpdated;

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isDeleting = false;
  bool _hasLinkedRecords = false;
  int _invoiceCount = 0;
  int _tripCount = 0;

  @override
  void initState() {
    super.initState();
    _checkLinkedRecords();
  }

  Future<void> _checkLinkedRecords() async {
    final clientId = widget.client['id'] as int?;
    if (clientId == null) return;

    final invoices = await _supabaseService.getInvoices();
    final trips = await _supabaseService.getTripOrders();

    final clientInvoices = invoices.where((inv) => inv['client_id'] == clientId).toList();
    final clientTrips = trips.where((trip) => trip['client_id'] == clientId).toList();

    if (mounted) {
      setState(() {
        _invoiceCount = clientInvoices.length;
        _tripCount = clientTrips.length;
        _hasLinkedRecords = _invoiceCount > 0 || _tripCount > 0;
      });
    }
  }

  Future<void> _confirmDelete() async {
    if (_hasLinkedRecords) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('تأكيد الحذف')),
          content: Text(context.tr('لا يمكن حذف الزبون لوجود فواتير أو رحلات مرتبطة')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('إلغاء')),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('حذف الزبون')),
        content: Text(context.tr('سيتم حذف هذا الزبون نهائياً')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('حذف')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _supabaseService.deleteClient(widget.client['id'] as int);
      if (!mounted) return;
      widget.onDeleted();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تم حذف الزبون بنجاح'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('خطأ في حذف الزبون: {0}', [e]))),
      );
    }
  }

  Future<void> _openEditDialog() async {
    final nameController = TextEditingController(text: widget.client['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: widget.client['phone']?.toString() ?? '');
    final addressController = TextEditingController(text: widget.client['address']?.toString() ?? '');
    final cityController = TextEditingController(text: widget.client['city']?.toString() ?? '');
    final nomContactController = TextEditingController(text: widget.client['nom_contact']?.toString() ?? '');
    final adresseFactController = TextEditingController(text: widget.client['adresse_facturation']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('تعديل بيانات الزبون')),
        content: SingleChildScrollView(
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: context.tr('الاسم / اسم الشركة')),
                ),
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(labelText: context.tr('الهاتف')),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: nomContactController,
                  decoration: InputDecoration(labelText: context.tr('اسم جهة الاتصال')),
                ),
                TextFormField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: context.tr('العنوان')),
                ),
                TextFormField(
                  controller: adresseFactController,
                  decoration: InputDecoration(labelText: context.tr('عنوان الفاتورة')),
                ),
                TextFormField(
                  controller: cityController,
                  decoration: InputDecoration(labelText: context.tr('المدينة')),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('إلغاء')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('يرجى إدخال اسم الزبون'))),
                );
                return;
              }
              final data = {
                'name': name,
                'phone': phoneController.text.trim(),
                'address': addressController.text.trim(),
                'city': cityController.text.trim(),
                'nom_contact': nomContactController.text.trim(),
                'adresse_facturation': adresseFactController.text.trim(),
              };
              await _supabaseService.updateClient(
                widget.client['id'] as int,
                data,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              widget.onUpdated();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('تم تحديث البيانات بنجاح'))),
                );
              }
            },
            child: Text(context.tr('حفظ')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.client['name']?.toString() ?? context.tr('بدون اسم');
    final phone = widget.client['phone']?.toString() ?? '';
    final address = widget.client['address']?.toString() ?? '';
    final city = widget.client['city']?.toString() ?? '';
    final nomContact = widget.client['nom_contact']?.toString() ?? '';
    final adresseFact = widget.client['adresse_facturation']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('تفاصيل الزبون')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isDeleting ? null : _openEditDialog,
            tooltip: context.tr('تعديل البيانات'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isDeleting ? null : _confirmDelete,
            tooltip: context.tr('حذف'),
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(context.tr('الاسم / اسم الشركة'), name),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الهاتف'), phone),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('اسم جهة الاتصال'), nomContact),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('العنوان'), address),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('عنوان الفاتورة'), adresseFact.isNotEmpty ? adresseFact : context.tr('لا يوجد')),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('المدينة'), city),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('السجل'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildStatRow(context.tr('فواتير'), '$_invoiceCount', Icons.receipt),
                        const SizedBox(height: 8),
                        _buildStatRow(context.tr('رحلات'), '$_tripCount', Icons.local_shipping),
                        if (!_hasLinkedRecords) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr('لا توجد فواتير أو رحلات مسجلة'),
                                    style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
