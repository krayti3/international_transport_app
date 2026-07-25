import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';
import 'package:collection/collection.dart';
import 'package:international_transport_app/services/calculation_engine.dart';
import 'package:international_transport_app/services/supabase_service.dart';
import '../models/trip_order.dart';
import '../widgets/responsive_layout.dart';
import '../screens/trip_form_screen.dart';

// ignore_for_file: use_build_context_synchronously

class SecretaryDashboardScreen extends StatefulWidget {
  const SecretaryDashboardScreen({super.key});

  @override
  State<SecretaryDashboardScreen> createState() => _SecretaryDashboardScreenState();
}

class _SecretaryDashboardScreenState extends State<SecretaryDashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tripOrders = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;
  String? _error;

  int _totalClients = 0;
  int _activeTripOrders = 0;
  int _outstandingInvoices = 0;
  double _outstandingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [clientsRes, ordersRes, invoicesRes] = await Future.wait([
        _supabase.from('clients').select(),
        _supabase.from('trip_orders').select(),
        _supabase.from('invoices').select(),
      ]);

      final clients = List<Map<String, dynamic>>.from(clientsRes as List);
      final orders = List<Map<String, dynamic>>.from(ordersRes as List);
      final invoices = List<Map<String, dynamic>>.from(invoicesRes as List);

      int activeOrders = 0;
      int outstandingInvs = 0;
      double outstandingTotal = 0.0;

      for (final o in orders) {
        final s = (o['status'] ?? '').toString().toLowerCase();
        if (s == 'active' || s == 'pending') activeOrders++;
      }

      for (int i = 0; i < invoices.length; i++) {
        final inv = invoices[i];
        final s = (inv['status'] ?? '').toString().toLowerCase();
        if (s == 'pending' || s == 'overdue') {
          outstandingInvs++;
          outstandingTotal += (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      if (mounted) {
        setState(() {
          _clients = clients;
          _tripOrders = orders;
          _invoices = invoices;
          _totalClients = clients.length;
          _activeTripOrders = activeOrders;
          _outstandingInvoices = outstandingInvs;
          _outstandingAmount = outstandingTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteTripOrder(int id) async {
    final inUse = await _supabaseService.isTripOrderInUse(id);
    if (inUse) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن حذف أمر الرحلة لأنه مرتبط بمدفوعات أو رحلات فرعية')),
        );
      }
      return;
    }
    try {
      await _supabase.from('trip_orders').delete().eq('id', id);
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف أمر الرحلة بنجاح')),
        );
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحذف: $e')),
        );
      }
    }
  }

  Future<void> _deleteInvoice(int id) async {
    final inUse = await _supabaseService.isInvoiceInUse(id);
    if (inUse) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن حذف الفاتورة لأنها مرتبطة بتخصيصات دفع')),
        );
      }
      return;
    }
    try {
      await _supabase.from('invoices').delete().eq('id', id);
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفاتورة بنجاح')),
        );
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحذف: $e')),
        );
      }
    }
  }

  Future<void> _openAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final cityController = TextEditingController();
    final addressController = TextEditingController();
    bool isSaving = false;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة زبون جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم / اسم الشركة', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'المدينة', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      final city = cityController.text.trim();
                      final address = addressController.text.trim();

                      if (name.isEmpty || phone.isEmpty || city.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى ملء الحقول المطلوبة')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await _supabase.from('clients').insert({
                          'name': name,
                          'phone': phone,
                          'city': city,
                          'address': address,
                        });
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إضافة الزبون بنجاح')),
                          );
                        }
                        _loadData();
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ في الحفظ: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddInvoiceDialog() async {
    final clients = await _supabase.from('clients').select('id, name, city, default_bank_account, default_bank_account_id').order('name');
    final bankAccounts = await _supabase.from('bank_accounts').select().eq('is_active', true);
    final appSettings = await _supabase.from('app_settings').select('percentage, is_enabled').eq('id', 1).maybeSingle();
    
    final clientsList = List<Map<String, dynamic>>.from(clients as List);
    final bankAccountsList = List<Map<String, dynamic>>.from(bankAccounts as List);
    String? selectedBankAccountType = 'moroccan';
    final tvaPercentage = (appSettings?['percentage'] as num?)?.toDouble() ?? 20.0;
    final isTvaEnabled = appSettings?['is_enabled'] as bool? ?? true;
    final tvaRate = isTvaEnabled ? Decimal.parse(tvaPercentage.toString()) : Decimal.zero;
    
    int? selectedClientId;
    String? selectedBankAccountId;
    String inputMode = 'HT';
    Decimal amount = Decimal.zero;
    bool isSaving = false;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة فاتورة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'الزبون', border: OutlineInputBorder()),
                  items: clientsList
                      .toList()
                      .sorted((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''))
                      .map((client) {
                        final id = client['id'] as int;
                        final name = client['name']?.toString() ?? 'بدون اسم';
                        final city = client['city']?.toString() ?? '';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('$name ($city)'),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedClientId = val;
                      final client = clientsList.firstWhere((c) => c['id'] == val);
                      final defaultBankType = client['default_bank_account']?.toString();
                      if (defaultBankType == 'moroccan' || defaultBankType == 'european') {
                        selectedBankAccountType = defaultBankType;
                      } else {
                        final fallbackId = client['default_bank_account_id']?.toString();
                        if (fallbackId == 'moroccan' || fallbackId == 'european') {
                          selectedBankAccountType = fallbackId;
                        } else {
                          selectedBankAccountType = 'moroccan';
                        }
                      }
                      final defaultBankId = client['default_bank_account_id']?.toString();
                      if (defaultBankId != null && bankAccountsList.any((b) => b['id'] == defaultBankId)) {
                        selectedBankAccountId = defaultBankId;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الحساب البنكي', border: OutlineInputBorder()),
                  items: bankAccountsList
                      .toList()
                      .sorted((a, b) => (a['bank_name']?.toString() ?? '').compareTo(b['bank_name']?.toString() ?? ''))
                      .map((account) {
                        final id = account['id'].toString();
                        final bankName = account['bank_name']?.toString() ?? '';
                        final currency = account['currency']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text('$bankName ($currency)'),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedBankAccountId = val;
                    });
                  },
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'نوع الحساب البنكي', border: OutlineInputBorder()),
                  initialValue: selectedBankAccountType,
                  items: const [
                    DropdownMenuItem(value: 'moroccan', child: Text('🇲🇦 الحساب المغربي (MAD)')),
                    DropdownMenuItem(value: 'european', child: Text('🇪🇺 الحساب الأوروبي (EUR)')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedBankAccountType = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('HT'),
                        selected: inputMode == 'HT',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => inputMode = 'HT');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('TTC'),
                        selected: inputMode == 'TTC',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => inputMode = 'TTC');
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: inputMode == 'HT' ? 'المبلغ (HT)' : 'المبلغ (TTC)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null) {
                      setDialogState(() {
                        amount = Decimal.parse(parsed.toString());
                      });
                    }
                  },
                ),
                if (amount > Decimal.zero && tvaRate > Decimal.zero) ...[
                  const SizedBox(height: 12),
                  _buildCalculationDisplay(inputMode, amount, tvaRate),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (selectedClientId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى اختيار الزبون')),
                        );
                        return;
                      }
                      if (selectedBankAccountType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى اختيار نوع الحساب البنكي')),
                        );
                        return;
                      }
                      if (amount <= Decimal.zero) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        final supabaseService = SupabaseService();
                         await supabaseService.createInvoice(
                           clientId: selectedClientId!,
                           amount: amount,
                           inputMode: inputMode,
                           bankAccountId: selectedBankAccountId,
                           bankAccountType: selectedBankAccountType,
                           bankInfoText: null,
                         );
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إضافة الفاتورة بنجاح')),
                          );
                        }
                        _loadData();
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationDisplay(String mode, Decimal amount, Decimal tvaRate) {
    final settings = CalculationEngine.calculate(amount: amount, inputMode: mode, tvaRate: tvaRate);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('HT:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(settings.htAmount.toStringAsFixed(2)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TVA:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(settings.tvaAmount.toStringAsFixed(2)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TTC:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(settings.ttcAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتمل';
      case 'overdue':
        return 'متأخر';
      case 'paid':
        return 'مدفوع';
      case 'partially_paid':
        return 'مدفوع جزئياً';
      case 'unpaid':
        return 'غير مدفوع';
      default:
        return status ?? '—';
    }
  }

  String _clientName(String? clientId) {
    if (clientId == null) return 'غير محدد';
    final client = _clients.firstWhere(
      (c) => c['id']?.toString() == clientId.toString(),
      orElse: () => const <String, dynamic>{},
    );
    return client['name']?.toString() ?? 'غير محدد';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('لوحة تحكم السكرتيرة'),
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text('حدث خطأ: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppConstrained(
                        maxWidth: 1200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary cards row
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final cardWidth = (constraints.maxWidth - 48) / 4;
                                return Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: _StatCard(
                                        title: 'إجمالي العملاء',
                                        value: '$_totalClients',
                                        icon: Icons.people_rounded,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _StatCard(
                                        title: 'أوامر الرحلات النشطة',
                                        value: '$_activeTripOrders',
                                        icon: Icons.local_shipping_rounded,
                                        color: Theme.of(context).colorScheme.tertiary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _StatCard(
                                        title: 'الفواتير المستحقة',
                                        value: '$_outstandingInvoices',
                                        icon: Icons.receipt_long_rounded,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _StatCard(
                                        title: 'إجمالي المبالغ المستحقة',
                                        value: '${NumberFormat('#,##0.00').format(_outstandingAmount)} DH',
                                        icon: Icons.attach_money_rounded,
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Quick entry buttons
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _openAddClientDialog,
                                  icon: const Icon(Icons.person_add_rounded),
                                  label: const Text('إدخال زبون جديد'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _openAddInvoiceDialog,
                                  icon: const Icon(Icons.add_card_rounded),
                                  label: const Text('إدخال فاتورة جديدة'),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Theme.of(context).colorScheme.primary,
                                     foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                   ),
                                 ),
                                 ElevatedButton.icon(
                                   onPressed: () {
                                     Navigator.push(
                                       context,
                                       MaterialPageRoute(builder: (context) => const TripFormScreen()),
                                     );
                                   },
                                   icon: const Icon(Icons.add_road_rounded),
                                   label: const Text('إنشاء أمر رحلة جديد'),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Theme.of(context).colorScheme.tertiary,
                                     foregroundColor: Theme.of(context).colorScheme.onTertiary,
                                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                   ),
                                 ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Recent Trip Orders
                            Text(
                              'أوامر الرحلات الأخيرة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (_tripOrders.isEmpty)
                              Card(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(child: Text('لا توجد أوامر رحلات')),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: PaginatedDataTable(
                                  columns: const [
                                    DataColumn(label: Text('#')),
                                    DataColumn(label: Text('العميل')),
                                    DataColumn(label: Text('المسار')),
                                    DataColumn(label: Text('التاريخ')),
                                    DataColumn(label: Text('الحالة')),
                                    DataColumn(label: Text('السائق')),
                                    DataColumn(label: Text('إجراءات')),
                                  ],
                                  source: _TripOrdersDataSource(
                                    tripOrders: _tripOrders,
                                    onView: (order) {
                                      final tripOrder = TripOrder.fromMap(order);
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('أمر رحلة #${order['id'] ?? '?'}'),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('العميل: ${_clientName(order['client_id']?.toString())}'),
                                                Text('المسار: ${order['route']?.toString() ?? '—'}'),
                                                Text('السعر: ${NumberFormat('#,##0.00').format(tripOrder.price)} DH'),
                                                Text('التاريخ: ${order['departure_date']?.toString() ?? '—'}'),
                                                Text('الحالة: ${_statusLabel(order['status']?.toString())}'),
                                                Text('الاتجاه: ${order['direction']?.toString() ?? 'outbound'}'),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
                                          ],
                                        ),
                                      );
                                    },
                                    onDelete: (id) => _deleteTripOrder(id),
                                  ),
                                  rowsPerPage: 8,
                                ),
                              ),

                            const SizedBox(height: 28),

                            // Recent Invoices
                            Text(
                              'الفواتير الأخيرة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (_invoices.isEmpty)
                              Card(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(child: Text('لا توجد فواتير')),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: PaginatedDataTable(
                                  columns: const [
                                    DataColumn(label: Text('#')),
                                    DataColumn(label: Text('رقم الفاتورة')),
                                    DataColumn(label: Text('العميل')),
                                    DataColumn(label: Text('المبلغ الإجمالي')),
                                    DataColumn(label: Text('المدفوع')),
                                    DataColumn(label: Text('الحالة')),
                                    DataColumn(label: Text('إجراءات')),
                                  ],
                                  source: _InvoicesDataSource(
                                    invoices: _invoices,
                                    onView: (invoice) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('فاتورة #${invoice['id'] ?? '?'}'),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('رقم الفاتورة: ${invoice['invoice_number']?.toString() ?? '—'}'),
                                                Text('العميل: ${_clientName(invoice['client_id']?.toString())}'),
                                                Text('المبلغ الإجمالي: ${NumberFormat('#,##0.00').format((invoice['total_amount'] as num?)?.toDouble() ?? 0.0)} DH'),
                                                Text('المدفوع: ${NumberFormat('#,##0.00').format((invoice['paid_amount'] as num?)?.toDouble() ?? 0.0)} DH'),
                                                Text('الحالة: ${_statusLabel(invoice['status']?.toString())}'),
                                                Text('تاريخ الإصدار: ${invoice['issue_date']?.toString() ?? '—'}'),
                                                Text('تاريخ الاستحقاق: ${invoice['due_date']?.toString() ?? '—'}'),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
                                          ],
                                        ),
                                      );
                                    },
                                    onDelete: (id) => _deleteInvoice(id),
                                  ),
                                  rowsPerPage: 8,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          if (Theme.of(context).brightness == Brightness.light)
            BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                radius: 18,
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TripOrdersDataSource extends DataTableSource {
  final List<Map<String, dynamic>> tripOrders;
  final Function(Map<String, dynamic>) onView;
  final Function(int) onDelete;

  _TripOrdersDataSource({
    required this.tripOrders,
    required this.onView,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= tripOrders.length) return null;
    final order = tripOrders[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text('#${order['id']?.toString() ?? '—'}')),
        DataCell(Text(order['client_id']?.toString() ?? 'غير محدد')),
        DataCell(Text(order['route']?.toString() ?? '—')),
        DataCell(Text(order['departure_date']?.toString() ?? '—')),
        DataCell(_StatusChip(status: order['status']?.toString())),
        DataCell(Text(order['driver_id']?.toString() ?? '—')),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_rounded, size: 20, color: Colors.blue),
                tooltip: 'عرض',
                onPressed: () => onView(order),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                tooltip: 'حذف',
                onPressed: () {
                  if (order['id'] != null) onDelete(order['id'] as int);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => tripOrders.length;

  @override
  int get selectedRowCount => 0;
}

class _InvoicesDataSource extends DataTableSource {
  final List<Map<String, dynamic>> invoices;
  final Function(Map<String, dynamic>) onView;
  final Function(int) onDelete;

  _InvoicesDataSource({
    required this.invoices,
    required this.onView,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= invoices.length) return null;
    final invoice = invoices[index];
    final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text('#${invoice['id']?.toString() ?? '—'}')),
        DataCell(Text(invoice['invoice_number']?.toString() ?? '—')),
        DataCell(Text(invoice['client_id']?.toString() ?? 'غير محدد')),
        DataCell(Text('${NumberFormat('#,##0.00').format(totalAmount)} DH')),
        DataCell(Text('${NumberFormat('#,##0.00').format(paidAmount)} DH')),
        DataCell(_StatusChip(status: invoice['status']?.toString())),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_rounded, size: 20, color: Colors.blue),
                tooltip: 'عرض',
                onPressed: () => onView(invoice),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                tooltip: 'حذف',
                onPressed: () {
                  if (invoice['id'] != null) onDelete(invoice['id'] as int);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => invoices.length;

  @override
  int get selectedRowCount => 0;
}

class _StatusChip extends StatelessWidget {
  final String? status;

  const _StatusChip({this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.teal;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'overdue':
        color = Colors.red;
        break;
      case 'paid':
        color = Colors.green;
        break;
      case 'partially_paid':
        color = Colors.orange;
        break;
      case 'unpaid':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        _label(status),
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  String _label(String? status) {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتمل';
      case 'overdue':
        return 'متأخر';
      case 'paid':
        return 'مدفوع';
      case 'partially_paid':
        return 'مدفوع جزئياً';
      case 'unpaid':
        return 'غير مدفوع';
      default:
        return status ?? '—';
    }
  }
}
