import 'package:flutter/material.dart';
import 'package:international_transport_app/models/client.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../l10n/app_localizations.dart';
import 'client_statement_screen.dart';
import 'customer_detail_screen.dart';
import 'location_picker_screen.dart';

// ignore_for_file: use_build_context_synchronously

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

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
    final invoices = await _supabaseService.getInvoices();

    final Map<String, DateTime> lastInvoiceDates = {};
    for (final inv in invoices) {
      final date = inv.issueDate;
      if (date == null) continue;
      final key = inv.clientId.toString();
      final existing = lastInvoiceDates[key];
      if (existing == null || date.isAfter(existing)) {
        lastInvoiceDates[key] = date;
      }
    }

    clients.sort((a, b) {
      final aDate = lastInvoiceDates[a.id?.toString() ?? ''];
      final bDate = lastInvoiceDates[b.id?.toString() ?? ''];

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return -1;
      if (bDate == null) return 1;

      return bDate.compareTo(aDate);
    });

    setState(() {
      _clients = clients;
      _filteredClients = clients;
      _isLoading = false;
    });
  }

  void _filterClients() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredClients = _clients.where((client) {
        if (_statusFilter == 'active' && !client.isActive) return false;
        if (_statusFilter == 'inactive' && client.isActive) return false;
        if (query.isEmpty) return true;
        final name = client.name.toLowerCase();
        final phone = client.phone.toLowerCase();
        final city = client.city?.toLowerCase() ?? '';
        final address = client.address?.toLowerCase() ?? '';
        final nomContact = client.nomContact?.toLowerCase() ?? '';
        final adresseFact = client.adresseFacturation?.toLowerCase() ?? '';
        final email = client.email.toLowerCase();
        final ice = client.ice.toLowerCase();
        return name.contains(query) ||
            phone.contains(query) ||
            city.contains(query) ||
            address.contains(query) ||
            nomContact.contains(query) ||
            adresseFact.contains(query) ||
            email.contains(query) ||
            ice.contains(query);
      }).toList();
    });
  }

  Future<Map<String, dynamic>> _getClientInvoiceStats(int? clientId) async {
    if (clientId == null) return {'lastInvoice': '-', 'count': 0};
    final invoices = await _supabaseService.getInvoices();
    final currentYear = DateTime.now().year;
    final clientInvoices = invoices.where((inv) {
      if (inv.clientId != clientId.toString()) return false;
      final date = inv.issueDate;
      if (date == null) return false;
      return date.year == currentYear;
    }).toList();

    String lastInvoice = '-';
    if (clientInvoices.isNotEmpty) {
      clientInvoices.sort((a, b) => (b.issueDate ?? DateTime(0)).compareTo(a.issueDate ?? DateTime(0)));
      lastInvoice = clientInvoices.first.invoiceNumber;
    }

    return {'lastInvoice': lastInvoice, 'count': clientInvoices.length};
  }

  Future<void> _openAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final nomContactController = TextEditingController();

    final iceController = TextEditingController();
    final shippingLine1Controller = TextEditingController();
    final shippingLine2Controller = TextEditingController();
    final shippingLine3Controller = TextEditingController();
    final shippingLine4Controller = TextEditingController();
    final shippingCityController = TextEditingController();
    final shippingPostalController = TextEditingController();
    final shippingCountryController = TextEditingController();
    final emailController = TextEditingController();
    final currencyController = TextEditingController();

    final sysSettings = await _supabaseService.getSystemSettings();
    final defaultCurrency = sysSettings?['default_currency']?.toString() ?? 'MAD';
    final defaultCountry = sysSettings?['company_country']?.toString() ?? 'Maroc';

    currencyController.text = defaultCurrency;
    shippingCountryController.text = defaultCountry;

    double? pickedLat;
    double? pickedLng;
    bool isActive = true;
    bool invoiceWithTva = false;

    String? selectedDefaultBankAccount = 'moroccan';
    final formKey = GlobalKey<FormState>();
    int selectedTab = 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('إضافة زبون جديد')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: context.tr('الاسم / اسم الشركة')),
                    ),
                    TextFormField(
                      controller: iceController,
                      decoration: InputDecoration(labelText: 'ICE (التعريف الضريبي)'),
                    ),
                    TextFormField(
                      initialValue: '-',
                      decoration: const InputDecoration(labelText: 'آخر فاتورة هذه السنة'),
                      enabled: false,
                    ),
                     SwitchListTile(
                       title: const Text('مفعل'),
                       value: isActive,
                       onChanged: (val) {
                         isActive = val;
                         setDialogState(() {});
                       },
                      ),
                       TextFormField(
                        initialValue: '0',
                       decoration: const InputDecoration(labelText: 'عدد الفواتر للسنة الحالية'),
                       enabled: false,
                     ),
                     Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() => selectedTab = 0),
                            style: selectedTab == 0 
                              ? ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor)
                              : null,
                            child: Text(context.tr('العنوان')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() => selectedTab = 1),
                            style: selectedTab == 1 
                              ? ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor)
                              : null,
                            child: Text(context.tr('البيانات البنكية')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectedTab == 0)
                      Column(
                        children: [
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
                            controller: emailController,
                            decoration: InputDecoration(labelText: 'EMAIL المراسلات'),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          Text(context.tr('عنوان الشحن / التفريغ'), style: TextStyle(fontWeight: FontWeight.bold)),
                          TextFormField(
                            controller: shippingLine1Controller,
                            decoration: InputDecoration(labelText: 'العنوان 1'),
                          ),
                          TextFormField(
                            controller: shippingLine2Controller,
                            decoration: InputDecoration(labelText: 'العنوان 2'),
                          ),
                          TextFormField(
                            controller: shippingLine3Controller,
                            decoration: InputDecoration(labelText: 'العنوان 3'),
                          ),
                          TextFormField(
                            controller: shippingLine4Controller,
                            decoration: InputDecoration(labelText: 'العنوان 4'),
                          ),
                          TextFormField(
                            controller: shippingCityController,
                            decoration: InputDecoration(labelText: 'المدينة'),
                          ),
                          TextFormField(
                            controller: shippingPostalController,
                            decoration: InputDecoration(labelText: 'رمز البريد'),
                          ),
                          TextFormField(
                            controller: shippingCountryController,
                            decoration: InputDecoration(labelText: 'الدولة'),
                          ),
                          StatefulBuilder(
                            builder: (context, setStateSB) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push<Map<String, double>>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LocationPickerScreen(
                                          initialLatitude: pickedLat,
                                          initialLongitude: pickedLng,
                                        ),
                                      ),
                                    );
                                    if (result != null) {
                                      pickedLat = result['lat'] as double;
                                      pickedLng = result['lng'] as double;
                                      setStateSB(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.map),
                                  label: const Text('تحديد الموقع على الخريطة'),
                                ),
                                if (pickedLat != null && pickedLng != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('الإحداثيات: $pickedLat, $pickedLng'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'الحساب البنكي الافتراضي', border: const OutlineInputBorder()),
                            initialValue: selectedDefaultBankAccount,
                            items: const [
                              DropdownMenuItem(value: 'moroccan', child: Text('🇲🇦 الحساب المغربي (MAD)')),
                              DropdownMenuItem(value: 'european', child: Text('🇪🇺 الحساب الأوروبي (EUR)')),
                            ],
                            onChanged: (val) {
                              selectedDefaultBankAccount = val;
                            },
                            validator: (value) => value == null ? 'يرجى اختيار حساب بنكي' : null,
                          ),
                           DropdownButtonFormField<String>(
                             decoration: InputDecoration(labelText: 'العملة', border: const OutlineInputBorder()),
                             initialValue: currencyController.text,
                             items: const [
                               DropdownMenuItem(value: 'MAD', child: Text('MAD - درهم')),
                               DropdownMenuItem(value: 'EUR', child: Text('EUR - يورو')),
                               DropdownMenuItem(value: 'USD', child: Text('USD - دولار')),
                             ],
                             onChanged: (val) {
                               currencyController.text = val!;
                             },
                           ),
                           const SizedBox(height: 12),
                           SwitchListTile(
                             title: const Text('فواتير ب TVA'),
                             value: invoiceWithTva,
                             onChanged: (val) {
                               invoiceWithTva = val;
                               setDialogState(() {});
                             },
                           ),
                        ],
                      ),
                  ],
                );
              },
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
                if (!formKey.currentState!.validate()) return;
              final newClient = Client(
                name: name,
                phone: phoneController.text.trim(),
                nomContact: nomContactController.text.trim(),
                defaultBankAccount: selectedDefaultBankAccount,
                ice: iceController.text.trim(),
                shippingAddressLine1: shippingLine1Controller.text.trim(),
                shippingAddressLine2: shippingLine2Controller.text.trim(),
                shippingAddressLine3: shippingLine3Controller.text.trim(),
                shippingAddressLine4: shippingLine4Controller.text.trim(),
                shippingCity: shippingCityController.text.trim(),
                shippingPostalCode: shippingPostalController.text.trim(),
                shippingCountry: shippingCountryController.text.trim(),
                shippingLatitude: pickedLat,
                shippingLongitude: pickedLng,
                currency: currencyController.text,
                email: emailController.text.trim(),
                isActive: isActive,
                invoiceWithTva: invoiceWithTva,
              );
              await _supabaseService.addClient(newClient);
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

  Future<void> _exportClientPdf(Client client) async {
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
        invoice.clientId == (client.id?.toString() ?? '')
      ).toList();

      clientInvoices.sort((a, b) {
        final dateA = a.issueDate ?? DateTime(0);
        final dateB = b.issueDate ?? DateTime(0);
        return dateA.compareTo(dateB);
      });

      await PdfService.instance.previewAndPrint(
        client: client.toMap(),
        transactions: clientInvoices.map((e) => e.toMap()).toList(),
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

  Future<void> _openEditClientDialog(Client client) async {
    final stats = await _getClientInvoiceStats(client.id);
    final lastInvoice = stats['lastInvoice'] as String;
    final invoiceCount = stats['count'] as int;

    final nameController = TextEditingController(text: client.name);
    final phoneController = TextEditingController(text: client.phone);
    final nomContactController = TextEditingController(text: client.nomContact);

    final iceController = TextEditingController(text: client.ice);
    final shippingLine1Controller = TextEditingController(text: client.shippingAddressLine1);
    final shippingLine2Controller = TextEditingController(text: client.shippingAddressLine2);
    final shippingLine3Controller = TextEditingController(text: client.shippingAddressLine3);
    final shippingLine4Controller = TextEditingController(text: client.shippingAddressLine4);
    final shippingCityController = TextEditingController(text: client.shippingCity);
    final shippingPostalController = TextEditingController(text: client.shippingPostalCode);
    final shippingCountryController = TextEditingController(text: client.shippingCountry);
    final emailController = TextEditingController(text: client.email);
    final currencyController = TextEditingController(text: client.currency);

    double? pickedLat = client.shippingLatitude;
    double? pickedLng = client.shippingLongitude;
    bool isActiveValue = client.isActive;
    bool invoiceWithTvaValue = client.invoiceWithTva;

    String? selectedDefaultBankAccount = client.defaultBankAccount ??
        (client.defaultBankAccountId == 'moroccan' || client.defaultBankAccountId == 'european'
            ? client.defaultBankAccountId
            : 'moroccan');
    final formKey = GlobalKey<FormState>();
    int selectedTab = 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('تعديل بيانات الزبون')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setDialogState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: context.tr('الاسم / اسم الشركة')),
                  ),
                  TextFormField(
                    controller: iceController,
                    decoration: InputDecoration(labelText: 'ICE (التعريف الضريبي)'),
                  ),
                  TextFormField(
                    initialValue: lastInvoice,
                    decoration: const InputDecoration(labelText: 'آخر فاتورة هذه السنة'),
                    enabled: false,
                  ),
                  SwitchListTile(
                    title: const Text('مفعل'),
                    value: isActiveValue,
                    onChanged: (val) {
                      isActiveValue = val;
                      setDialogState(() {});
                    },
                   ),
                     TextFormField(
                       initialValue: invoiceCount.toString(),
                      decoration: const InputDecoration(labelText: 'عدد الفواتر للسنة الحالية'),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setDialogState(() => selectedTab = 0),
                           style: selectedTab == 0
                             ? ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor)
                             : null,
                          child: Text(context.tr('العنوان')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setDialogState(() => selectedTab = 1),
                           style: selectedTab == 1
                             ? ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor)
                             : null,
                          child: Text(context.tr('البيانات البنكية')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (selectedTab == 0)
                    Column(
                      children: [
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
                          controller: emailController,
                          decoration: InputDecoration(labelText: 'EMAIL المراسلات'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        Text(context.tr('عنوان الشحن / التفريغ'), style: TextStyle(fontWeight: FontWeight.bold)),
                        TextFormField(
                          controller: shippingLine1Controller,
                          decoration: InputDecoration(labelText: 'العنوان 1'),
                        ),
                        TextFormField(
                          controller: shippingLine2Controller,
                          decoration: InputDecoration(labelText: 'العنوان 2'),
                        ),
                        TextFormField(
                          controller: shippingLine3Controller,
                          decoration: InputDecoration(labelText: 'العنوان 3'),
                        ),
                        TextFormField(
                          controller: shippingLine4Controller,
                          decoration: InputDecoration(labelText: 'العنوان 4'),
                        ),
                        TextFormField(
                          controller: shippingCityController,
                          decoration: InputDecoration(labelText: 'المدينة'),
                        ),
                        TextFormField(
                          controller: shippingPostalController,
                          decoration: InputDecoration(labelText: 'رمز البريد'),
                        ),
                        TextFormField(
                          controller: shippingCountryController,
                          decoration: InputDecoration(labelText: 'الدولة'),
                        ),
                        StatefulBuilder(
                          builder: (context, setStateSB) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push<Map<String, double>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LocationPickerScreen(
                                        initialLatitude: pickedLat,
                                        initialLongitude: pickedLng,
                                      ),
                                    ),
                                  );
                                  if (result != null) {
                                    pickedLat = result['lat'] as double;
                                    pickedLng = result['lng'] as double;
                                    setStateSB(() {});
                                  }
                                },
                                icon: const Icon(Icons.map),
                                label: const Text('تحديد الموقع على الخريطة'),
                              ),
                              if (pickedLat != null && pickedLng != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('الإحداثيات: $pickedLat, $pickedLng'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'الحساب البنكي الافتراضي',
                            border: const OutlineInputBorder(),
                          ),
                          initialValue: selectedDefaultBankAccount,
                          items: const [
                            DropdownMenuItem(value: 'moroccan', child: Text('🇲🇦 الحساب المغربي')),
                            DropdownMenuItem(value: 'european', child: Text('🇪🇺 الحساب الأوروبي')),
                          ],
                          onChanged: (val) {
                            selectedDefaultBankAccount = val;
                          },
                          validator: (value) => value == null ? 'يرجى اختيار حساب بنكي' : null,
                        ),
                         DropdownButtonFormField<String>(
                           initialValue: currencyController.text,
                           decoration: InputDecoration(labelText: 'العملة', border: const OutlineInputBorder()),
                           items: const [
                             DropdownMenuItem(value: 'MAD', child: Text('MAD - درهم')),
                             DropdownMenuItem(value: 'EUR', child: Text('EUR - يورو')),
                             DropdownMenuItem(value: 'USD', child: Text('USD - دولار')),
                           ],
                           onChanged: (val) {
                             currencyController.text = val!;
                           },
                         ),
                         const SizedBox(height: 12),
                         SwitchListTile(
                           title: const Text('فواتير ب TVA'),
                           value: invoiceWithTvaValue,
                           onChanged: (val) {
                             invoiceWithTvaValue = val;
                             setDialogState(() {});
                           },
                         ),
                      ],
                    ),
                ],
              ),
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
                if (!formKey.currentState!.validate()) return;
                final updatedClient = client.copyWith(
                name: name,
                phone: phoneController.text.trim(),
                nomContact: nomContactController.text.trim(),
                defaultBankAccount: selectedDefaultBankAccount,
                ice: iceController.text.trim(),
                shippingAddressLine1: shippingLine1Controller.text.trim(),
                shippingAddressLine2: shippingLine2Controller.text.trim(),
                shippingAddressLine3: shippingLine3Controller.text.trim(),
                shippingAddressLine4: shippingLine4Controller.text.trim(),
                shippingCity: shippingCityController.text.trim(),
                shippingPostalCode: shippingPostalController.text.trim(),
                shippingCountry: shippingCountryController.text.trim(),
                shippingLatitude: pickedLat,
                shippingLongitude: pickedLng,
                currency: currencyController.text,
                email: emailController.text.trim(),
                isActive: isActiveValue,
                invoiceWithTva: invoiceWithTvaValue,
              );
              await _supabaseService.updateClient(
                updatedClient,
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

  Future<void> _showActionsSheet(Client client) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(client.name),
              subtitle: Text('${client.phone} • ${client.city}'),
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
                      clientId: client.id ?? 0,
                      clientName: client.name,
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
        actions: const [],
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ToggleButtons(
                    isSelected: [
                      _statusFilter == 'all',
                      _statusFilter == 'active',
                      _statusFilter == 'inactive',
                    ],
                    onPressed: (index) {
                      _statusFilter = ['all', 'active', 'inactive'][index];
                      _filterClients();
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: Theme.of(context).primaryColor,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('الكل'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('مفعل'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('غير مفعل'),
                      ),
                    ],
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
                              if (client.phone.isNotEmpty) client.phone,
                              if (client.city?.isNotEmpty ?? false) client.city!,
                            ];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerDetailScreen(
                                        client: client.toMap(),
                                        onDeleted: _loadClients,
                                        onUpdated: _loadClients,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () => _showActionsSheet(client),
                                child: ListTile(
                                  leading: Icon(
                                    client.isActive ? Icons.check_circle : Icons.cancel,
                                    color: client.isActive ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  title: Text(
                                    client.name,
                                    style: TextStyle(
                                      color: client.isActive ? null : Colors.grey,
                                      decoration: client.isActive ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  subtitle: Text(
                                    subtitleParts.join(' • '),
                                    style: TextStyle(
                                      color: client.isActive ? null : Colors.grey,
                                    ),
                                  ),
                                  trailing: widget.isAdmin
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: client.isActive ? null : Colors.grey,
                                          ),
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
