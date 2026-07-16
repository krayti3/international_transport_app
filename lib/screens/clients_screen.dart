import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../l10n/app_localizations.dart';
import 'client_statement_screen.dart';
import 'customer_detail_screen.dart';

// ignore_for_file: use_build_context_synchronously

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClients);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    final clients = await _supabaseService.getClients();
    setState(() {
      _clients = clients;
      _filteredClients = clients;
      _isLoading = false;
    });
  }

  void _filterClients() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredClients = _clients);
      return;
    }

    setState(() {
      _filteredClients = _clients.where((client) {
        final name = client['name']?.toString().toLowerCase() ?? '';
        final phone = client['phone']?.toString().toLowerCase() ?? '';
        final city = client['city']?.toString().toLowerCase() ?? '';
        final address = client['address']?.toString().toLowerCase() ?? '';
        final nomContact = client['nom_contact']?.toString().toLowerCase() ?? '';
        final adresseFact = client['adresse_facturation']?.toString().toLowerCase() ?? '';
        return name.contains(query) ||
            phone.contains(query) ||
            city.contains(query) ||
            address.contains(query) ||
            nomContact.contains(query) ||
            adresseFact.contains(query);
      }).toList();
    });
  }

  Future<void> _openAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final nomContactController = TextEditingController();
    final adresseFactController = TextEditingController();

    final bankAccounts = await _supabaseService.getBankAccounts();
    bankAccounts.sort((a, b) => (a['bank_name']?.toString() ?? '').compareTo(b['bank_name']?.toString() ?? ''));
    final bankAccountsList = List<Map<String, dynamic>>.from(bankAccounts as List);
    String? selectedDefaultBankAccountId;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('إضافة زبون جديد')),
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
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'الحساب البنكي الافتراضي', border: const OutlineInputBorder()),
                  items: bankAccountsList.map((account) {
                    final id = account['id'].toString();
                    final bankName = account['bank_name']?.toString() ?? '';
                    final currency = account['currency']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text('$bankName ($currency)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    selectedDefaultBankAccountId = val;
                  },
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
               if (selectedDefaultBankAccountId != null) {
                 data['default_bank_account_id'] = selectedDefaultBankAccountId!;
               }
              await _supabaseService.addClient(data);
              if (!context.mounted) return;
              Navigator.pop(context);
              await _loadClients();
            },
            child: Text(context.tr('حفظ')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportClientPdf(Map<String, dynamic> client) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.tr('جاري إنشاء كشف الحساب...')),
          ],
        ),
      ),
    );

    try {
      final invoices = await _supabaseService.getInvoices();
      final clientInvoices = invoices.where((invoice) =>
        invoice['client_id']?.toString() == client['id']?.toString()
      ).toList();

      clientInvoices.sort((a, b) {
        final dateA = a['issue_date']?.toString() ?? '';
        final dateB = b['issue_date']?.toString() ?? '';
        return dateA.compareTo(dateB);
      });

      await PdfService.instance.previewAndPrint(
        client: client,
        transactions: clientInvoices,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('خطأ في إنشاء كشف الحساب: {0}', [e]))),
      );
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _openEditClientDialog(Map<String, dynamic> client) async {
    final nameController = TextEditingController(text: client['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: client['phone']?.toString() ?? '');
    final addressController = TextEditingController(text: client['address']?.toString() ?? '');
    final cityController = TextEditingController(text: client['city']?.toString() ?? '');
    final nomContactController = TextEditingController(text: client['nom_contact']?.toString() ?? '');
    final adresseFactController = TextEditingController(text: client['adresse_facturation']?.toString() ?? '');

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
                client['id'] as int,
                data,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              await _loadClients();
            },
            child: Text(context.tr('حفظ')),
          ),
        ],
      ),
    );
  }

  Future<void> _showActionsSheet(Map<String, dynamic> client) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(client['name'] ?? context.tr('بدون اسم')),
              subtitle: Text('${client['phone'] ?? ''} • ${client['city'] ?? ''}'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(context.tr('تصدير كشف الحساب (PDF)')),
              onTap: () {
                Navigator.pop(context);
                _exportClientPdf(client);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: Text(context.tr('كشف حساب تفصيلي')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientStatementScreen(
                      clientId: int.tryParse(client['id']?.toString() ?? '') ?? 0,
                      clientName: client['name']?.toString() ?? context.tr('بدون اسم'),
                    ),
                  ),
                );
              },
            ),
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: Text(context.tr('تعديل البيانات')),
                onTap: () {
                  Navigator.pop(context);
                  _openEditClientDialog(client);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('إدارة الزبائن')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: widget.isAdmin ? () {
              // Bulk delete placeholder
            } : null,
            tooltip: context.tr('حذف'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('بحث...'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredClients.isEmpty
                      ? Center(child: Text(context.tr('لا يوجد زبائن حالياً')))
                      : ListView.builder(
                          itemCount: _filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = _filteredClients[index];
                            final subtitleParts = <String>[
                              if (client['phone']?.toString().isNotEmpty ?? false) client['phone'].toString(),
                              if (client['city']?.toString().isNotEmpty ?? false) client['city'].toString(),
                            ];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerDetailScreen(
                                        client: client,
                                        onDeleted: _loadClients,
                                        onUpdated: _loadClients,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () => _showActionsSheet(client),
                                child: ListTile(
                                  title: Text(client['name'] ?? context.tr('بدون اسم')),
                                  subtitle: Text(subtitleParts.join(' • ')),
                                  trailing: widget.isAdmin
                                      ? IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () => _openEditClientDialog(client),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddClientDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
