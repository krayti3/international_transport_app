import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:international_transport_app/models/client.dart';
import 'package:international_transport_app/repositories/invoice_repository.dart';
import 'package:international_transport_app/repositories/bank_account_repository.dart';
import 'package:international_transport_app/repositories/cash_box_repository.dart';
import '../cubits/clients_cubit.dart';
import '../cubits/customer_detail_cubit.dart';
import '../../../services/pdf_service.dart';
import '../../../l10n/app_localizations.dart';
import 'customer_detail_screen.dart';
import '../../../screens/location_picker_screen.dart';

// ignore_for_file: use_build_context_synchronously

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsCubit, ClientsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('إدارة الزبائن')),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _openAddClientDialog(context),
                tooltip: 'إضافة زبون',
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.tr('بحث...'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => context.read<ClientsCubit>().onSearchChanged(''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: (value) => context.read<ClientsCubit>().onSearchChanged(value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ToggleButtons(
                  isSelected: [
                    state.statusFilter == 'all',
                    state.statusFilter == 'active',
                    state.statusFilter == 'inactive',
                  ],
                  onPressed: (index) {
                    final filter = ['all', 'active', 'inactive'][index];
                    context.read<ClientsCubit>().onStatusFilterChanged(filter);
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
                child: state.filteredClients.isEmpty
                    ? Center(child: Text(context.tr('لا يوجد زبائن حالياً')))
                    : ListView.builder(
                        itemCount: state.filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = state.filteredClients[index];
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
                                    builder: (_) => BlocProvider(
                                      create: (_) => CustomerDetailCubit(
                                        context.read<InvoiceRepository>(),
                                        context.read<BankAccountRepository>(),
                                        context.read<CashBoxRepository>(),
                                        client.id ?? 0,
                                      ),
                                      child: CustomerDetailScreen(
                                        client: client.toMap(),
                                        onDeleted: () => context.read<ClientsCubit>().loadClients(),
                                        onUpdated: () => context.read<ClientsCubit>().loadClients(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () => _showActionsSheet(context, client),
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
                                trailing: isAdmin
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          size: 20,
                                          color: client.isActive ? null : Colors.grey,
                                        ),
                                        onPressed: () => _openEditClientDialog(context, client),
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
        );
      },
    );
  }

  Future<void> _openAddClientDialog(BuildContext context) async {
    final cubit = context.read<ClientsCubit>();
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

    final defaultCurrency = await cubit.getDefaultCurrency();
    final defaultCountry = await cubit.getDefaultCountry();

    currencyController.text = defaultCurrency ?? 'MAD';
    shippingCountryController.text = defaultCountry ?? 'Maroc';

    double? pickedLat;
    double? pickedLng;
    bool isActive = true;
    bool invoiceWithTva = false;

    String? selectedDefaultBankAccount = 'moroccan';
    final formKey = GlobalKey<FormState>();
    int selectedTab = 0;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                      decoration: const InputDecoration(labelText: 'ICE (التعريف الضريبي)'),
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
                            decoration: const InputDecoration(labelText: 'EMAIL المراسلات'),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          Text(context.tr('عنوان الشحن / التفريغ'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextFormField(
                            controller: shippingLine1Controller,
                            decoration: const InputDecoration(labelText: 'العنوان 1'),
                          ),
                          TextFormField(
                            controller: shippingLine2Controller,
                            decoration: const InputDecoration(labelText: 'العنوان 2'),
                          ),
                          TextFormField(
                            controller: shippingLine3Controller,
                            decoration: const InputDecoration(labelText: 'العنوان 3'),
                          ),
                          TextFormField(
                            controller: shippingLine4Controller,
                            decoration: const InputDecoration(labelText: 'العنوان 4'),
                          ),
                          TextFormField(
                            controller: shippingCityController,
                            decoration: const InputDecoration(labelText: 'المدينة'),
                          ),
                          TextFormField(
                            controller: shippingPostalController,
                            decoration: const InputDecoration(labelText: 'رمز البريد'),
                          ),
                          TextFormField(
                            controller: shippingCountryController,
                            decoration: const InputDecoration(labelText: 'الدولة'),
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
                            decoration: const InputDecoration(labelText: 'الحساب البنكي الافتراضي', border: OutlineInputBorder()),
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
                            decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
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
            onPressed: () => Navigator.pop(dialogContext),
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
              await cubit.addClient(newClient);
              if (!context.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: Text(context.tr('حفظ')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportClientPdf(BuildContext context, Client client) async {
    if (!context.mounted) return;
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.tr('جاري إنشاء كشف الحساب...')),
            ],
          ),
        );
      },
    );

    try {
      final invoiceRepository = context.read<InvoiceRepository>();
      final invoices = await invoiceRepository.getInvoices();
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('خطأ في إنشاء كشف الحساب: {0}', [e]))),
      );
    } finally {
      if (context.mounted && dialogContext != null) {
        Navigator.pop(dialogContext!);
      }
    }
  }

  Future<void> _openEditClientDialog(BuildContext context, Client client) async {
    final cubit = context.read<ClientsCubit>();
    final stats = await cubit.getClientInvoiceStats(client.id);
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
      builder: (dialogContext) => AlertDialog(
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
                    decoration: const InputDecoration(labelText: 'ICE (التعريف الضريبي)'),
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
                          decoration: const InputDecoration(labelText: 'EMAIL المراسلات'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        Text(context.tr('عنوان الشحن / التفريغ'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextFormField(
                          controller: shippingLine1Controller,
                          decoration: const InputDecoration(labelText: 'العنوان 1'),
                        ),
                        TextFormField(
                          controller: shippingLine2Controller,
                          decoration: const InputDecoration(labelText: 'العنوان 2'),
                        ),
                        TextFormField(
                          controller: shippingLine3Controller,
                          decoration: const InputDecoration(labelText: 'العنوان 3'),
                        ),
                        TextFormField(
                          controller: shippingLine4Controller,
                          decoration: const InputDecoration(labelText: 'العنوان 4'),
                        ),
                        TextFormField(
                          controller: shippingCityController,
                          decoration: const InputDecoration(labelText: 'المدينة'),
                        ),
                        TextFormField(
                          controller: shippingPostalController,
                          decoration: const InputDecoration(labelText: 'رمز البريد'),
                        ),
                        TextFormField(
                          controller: shippingCountryController,
                          decoration: const InputDecoration(labelText: 'الدولة'),
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
                          decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
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
            onPressed: () => Navigator.pop(dialogContext),
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
              await cubit.updateClient(updatedClient);
              if (!context.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: Text(context.tr('حفظ')),
          ),
        ],
      ),
    );
  }

  Future<void> _showActionsSheet(BuildContext context, Client client) async {
    final cubit = context.read<ClientsCubit>();
    showModalBottomSheet(
      context: context,
      builder: (bottomContext) => Container(
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
                Navigator.pop(bottomContext);
                _exportClientPdf(context, client);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: Text(context.tr('كشف حساب تفصيلي')),
              onTap: () {
                Navigator.pop(bottomContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => CustomerDetailCubit(
                        context.read<InvoiceRepository>(),
                        context.read<BankAccountRepository>(),
                        context.read<CashBoxRepository>(),
                        client.id ?? 0,
                      ),
                      child: CustomerDetailScreen(
                        client: client.toMap(),
                        onDeleted: () => cubit.loadClients(),
                        onUpdated: () => cubit.loadClients(),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: Text(context.tr('تعديل البيانات')),
                onTap: () {
                  Navigator.pop(bottomContext);
                  _openEditClientDialog(context, client);
                },
              ),
          ],
        ),
      ),
    );
  }
}
