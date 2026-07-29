import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª: $e')),
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
          const SnackBar(content: Text('Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø­Ø°Ù Ø£Ù…Ø± Ø§Ù„Ø±Ø­Ù„Ø© Ù„Ø£Ù†Ù‡ Ù…Ø±ØªØ¨Ø· Ø¨Ù…Ø¯ÙÙˆØ¹Ø§Øª Ø£Ùˆ Ø±Ø­Ù„Ø§Øª ÙØ±Ø¹ÙŠØ©')),
        );
      }
      return;
    }
    try {
      await _supabase.from('trip_orders').delete().eq('id', id);
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ØªÙ… Ø­Ø°Ù Ø£Ù…Ø± Ø§Ù„Ø±Ø­Ù„Ø© Ø¨Ù†Ø¬Ø§Ø­')),
        );
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ Ø§Ù„Ø­Ø°Ù: $e')),
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
          const SnackBar(content: Text('Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø­Ø°Ù Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ù„Ø£Ù†Ù‡Ø§ Ù…Ø±ØªØ¨Ø·Ø© Ø¨ØªØ®ØµÙŠØµØ§Øª Ø¯ÙØ¹')),
        );
      }
      return;
    }
    try {
      await _supabase.from('invoices').delete().eq('id', id);
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ØªÙ… Ø­Ø°Ù Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø¨Ù†Ø¬Ø§Ø­')),
        );
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ Ø§Ù„Ø­Ø°Ù: $e')),
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
          title: const Text('Ø¥Ø¶Ø§ÙØ© Ø²Ø¨ÙˆÙ† Ø¬Ø¯ÙŠØ¯'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Ø§Ù„Ø§Ø³Ù… / Ø§Ø³Ù… Ø§Ù„Ø´Ø±ÙƒØ©', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Ø§Ù„Ù‡Ø§ØªÙ', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'Ø§Ù„Ù…Ø¯ÙŠÙ†Ø©', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Ø§Ù„Ø¹Ù†ÙˆØ§Ù†', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ø¥Ù„ØºØ§Ø¡')),
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
                          const SnackBar(content: Text('ÙŠØ±Ø¬Ù‰ Ù…Ù„Ø¡ Ø§Ù„Ø­Ù‚ÙˆÙ„ Ø§Ù„Ù…Ø·Ù„ÙˆØ¨Ø©')),
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
                            const SnackBar(content: Text('ØªÙ… Ø¥Ø¶Ø§ÙØ© Ø§Ù„Ø²Ø¨ÙˆÙ† Ø¨Ù†Ø¬Ø§Ø­')),
                          );
                        }
                        _loadData();
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ Ø§Ù„Ø­ÙØ¸: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ø­ÙØ¸'),
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
          title: const Text('Ø¥Ø¶Ø§ÙØ© ÙØ§ØªÙˆØ±Ø© Ø¬Ø¯ÙŠØ¯Ø©'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Ø§Ù„Ø²Ø¨ÙˆÙ†', border: OutlineInputBorder()),
                  items: clientsList
                      .toList()
                      .sorted((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''))
                      .map((client) {
                        final id = client['id'] as int;
                        final name = client['name']?.toString() ?? 'Ø¨Ø¯ÙˆÙ† Ø§Ø³Ù…';
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
                  decoration: const InputDecoration(labelText: 'Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¨Ù†ÙƒÙŠ', border: OutlineInputBorder()),
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
                   decoration: const InputDecoration(labelText: 'Ù†ÙˆØ¹ Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¨Ù†ÙƒÙŠ', border: OutlineInputBorder()),
                   initialValue: selectedBankAccountType,
                   items: const [
                     DropdownMenuItem(value: 'moroccan', child: Text('ðŸ‡²ðŸ‡¦ Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ù…ØºØ±Ø¨ÙŠ (MAD)')),
                     DropdownMenuItem(value: 'european', child: Text('ðŸ‡ªðŸ‡º Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø£ÙˆØ±ÙˆØ¨ÙŠ (EUR)')),
                   ],
                   onChanged: (val) {
                     setDialogState(() {
                       selectedBankAccountType = val;
                     });
                   },
                 ),
                 const SizedBox(height: 12),
                 Builder(
                   builder: (context) {
                     final selectedAccount = selectedBankAccountId != null
                         ? bankAccountsList.firstWhereOrNull((b) => b['id'].toString() == selectedBankAccountId)
                         : null;
                     final typeLabel = selectedBankAccountType == 'moroccan'
                         ? 'Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ù…ØºØ±Ø¨ÙŠ (MAD)'
                         : selectedBankAccountType == 'european'
                             ? 'Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø£ÙˆØ±ÙˆØ¨ÙŠ (EUR)'
                             : null;
                     final displayText = selectedAccount != null
                         ? 'Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¨Ù†ÙƒÙŠ Ø§Ù„Ù…Ø­Ø¯Ø¯: ${selectedAccount['bank_name']} (${selectedAccount['currency']})'
                         : typeLabel != null
                             ? 'Ù†ÙˆØ¹ Ø§Ù„Ø­Ø³Ø§Ø¨: $typeLabel'
                             : null;
                     if (displayText == null) return const SizedBox.shrink();
                     return Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(
                         color: Colors.green.withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.green),
                       ),
                       child: Row(
                         children: [
                           const Icon(Icons.payment, color: Colors.green, size: 18),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               displayText,
                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                             ),
                           ),
                         ],
                       ),
                     );
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
                    labelText: inputMode == 'HT' ? 'Ø§Ù„Ù…Ø¨Ù„Øº (HT)' : 'Ø§Ù„Ù…Ø¨Ù„Øº (TTC)',
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ø¥Ù„ØºØ§Ø¡')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (selectedClientId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ÙŠØ±Ø¬Ù‰ Ø§Ø®ØªÙŠØ§Ø± Ø§Ù„Ø²Ø¨ÙˆÙ†')),
                        );
                        return;
                      }
                      if (selectedBankAccountType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ÙŠØ±Ø¬Ù‰ Ø§Ø®ØªÙŠØ§Ø± Ù†ÙˆØ¹ Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¨Ù†ÙƒÙŠ')),
                        );
                        return;
                      }
                      if (amount <= Decimal.zero) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ÙŠØ±Ø¬Ù‰ Ø¥Ø¯Ø®Ø§Ù„ Ù…Ø¨Ù„Øº ØµØ­ÙŠØ­')),
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
                            const SnackBar(content: Text('ØªÙ… Ø¥Ø¶Ø§ÙØ© Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø¨Ù†Ø¬Ø§Ø­')),
                          );
                        }
                        _loadData();
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ø®Ø·Ø£: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ø­ÙØ¸'),
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
        return 'Ù†Ø´Ø·';
      case 'pending':
        return 'Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±';
      case 'completed':
        return 'Ù…ÙƒØªÙ…Ù„';
      case 'overdue':
        return 'Ù…ØªØ£Ø®Ø±';
      case 'paid':
        return 'Ù…Ø¯ÙÙˆØ¹';
      case 'partially_paid':
        return 'Ù…Ø¯ÙÙˆØ¹ Ø¬Ø²Ø¦ÙŠØ§Ù‹';
      case 'unpaid':
        return 'ØºÙŠØ± Ù…Ø¯ÙÙˆØ¹';
      default:
        return status ?? 'â€”';
    }
  }

  String _clientName(String? clientId) {
    if (clientId == null) return 'ØºÙŠØ± Ù…Ø­Ø¯Ø¯';
    final client = _clients.firstWhere(
      (c) => c['id']?.toString() == clientId.toString(),
      orElse: () => const <String, dynamic>{},
    );
    return client['name']?.toString() ?? 'ØºÙŠØ± Ù…Ø­Ø¯Ø¯';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Ù„ÙˆØ­Ø© ØªØ­ÙƒÙ… Ø§Ù„Ø³ÙƒØ±ØªÙŠØ±Ø©'),
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: CallbackShortcuts(
          bindings: {
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): () {
              if (mounted) _openNewTripOrderDialog(context);
            },
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI): () {
              if (mounted) _openAddInvoiceDialog();
            },
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Overdue invoices found')),
                );
              }
            },
          },
          child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Ø­Ø¯Ø« Ø®Ø·Ø£: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©')),
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
                          // Overdue invoice alert banner
                          if (_invoices.any((inv) => (inv['status'] ?? '').toString().toLowerCase() == 'overdue'))
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ã˜ÂªÃ™â€ Ã˜Â¨Ã™Å Ã™â€¡: Ã˜ÂªÃ™Ë†Ã˜Â¬Ã˜Â¯ Ã˜Â¹Ã˜Â¯Ã˜Â¯ Ã˜Â±Ã˜Â³Ã™â€¦ Ã˜Â§Ã™â€žÃ™ÂÃ˜Â§Ã˜ÂªÃ™Ë†Ã˜Â±Ã˜Â§Ã˜Âª Ã˜Â§Ã™â€žÃ™â€¦Ã˜ÂªÃ˜Â£Ã˜Â®Ã˜Â±Ã˜Â© Ã˜Â§Ã™â€žÃ˜Â¬Ã˜Â¯Ã™Å Ã˜Â¯Ã˜Â©',
                                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // Navigate to overdue invoices
                                    },
                                    child: const Text('Ã˜Â§Ã™â€žÃ˜Â¥Ã˜Â¶Ã˜Â§Ã˜Â±Ã˜Â©'),
                                  ),
                                ],
                              ),
                            ),

                            // Quick Actions bar
                            Text(
                              'Ã˜Â§Ã™â€žÃ˜Â¥Ã˜Â±Ã˜Â§Ã˜Âª Ã˜Â§Ã™â€žÃ˜Â³Ã˜Â±Ã™Å Ã˜Â¹Ã˜Â©',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _openNewTripOrderDialog(context),
                                  icon: const Icon(Icons.add_road_rounded),
                                  label: const Text('Ã˜ÂªÃ˜Â³Ã™â€žÃ™Å Ã™â€¦ Ã˜Â¹Ã™â€¡Ã˜Â¯Ã˜Â© Ã˜Â¬Ã˜Â¯Ã™Å Ã˜Â¯Ã˜Â©'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _openAddInvoiceDialog,
                                  icon: const Icon(Icons.add_card_rounded),
                                  label: const Text('Ã˜Â¥Ã™â€ Ã˜Â´Ã˜Â§Ã˜Â¡ Ã™ÂÃ˜Â§Ã˜ÂªÃ™Ë†Ã˜Â±Ã˜Â© Ã˜Â¬Ã˜Â¯Ã™Å Ã˜Â¯Ã˜Â©'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _openSettlePendingTripDialog(context),
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text('Ã˜ÂªÃ˜Â³Ã™Ë†Ã™Å Ã˜Â© Ã˜Â±Ã˜Â­Ã™â€žÃ˜Â© Ã˜Â§Ã™â€žÃ™â€¦Ã˜Â¹Ã™â€žÃ™â€šÃ˜Â©'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Pending Trip Orders Queue
                            if (_tripOrders.any((o) => (o['status'] ?? '').toString().toLowerCase() == 'pending')) ...[
                              Text(
                                'Ã˜Â§Ã™â€žÃ˜Â±Ã˜ÂªÃ˜Â¨ Ã˜Â§Ã™â€žÃ™â€¦Ã˜ÂªÃ˜Â§Ã™â€ Ã˜Å¸',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._tripOrders
                                  .where((o) => (o['status'] ?? '').toString().toLowerCase() == 'pending')
                                  .take(5)
                                  .map((order) => Card(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        child: ListTile(
                                          leading: const Icon(Icons.local_shipping_rounded, color: Colors.orange),
                                          title: Text(order['route']?.toString() ?? 'Ã˜Â±Ã˜Â­Ã™â€žÃ˜Â©'),
                                          subtitle: Text('Ã˜Â§Ã™â€žÃ˜Â¹Ã™â€¦Ã™Å Ã™â€ž: ${_clientName(order["client_id"]?.toString())}'),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                NumberFormat('#,##0.00').format((order['price'] as num?)?.toDouble() ?? 0.0),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_forward_ios, size: 16),
                                            ],
                                          ),
                                          onTap: () {
                                            final tripOrder = TripOrder.fromMap(order);
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('Ã˜Â£Ã™â€¦Ã˜Â± Ã˜Â±Ã˜Â­Ã™â€žÃ˜Â© #${order['id'] ?? '?'}'),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Ã˜Â§Ã™â€žÃ˜Â¹Ã™â€¦Ã™Å Ã™â€ž: ${_clientName(order['client_id']?.toString())}'),
                                                      Text('Ã˜Â§Ã™â€žÃ™â€¦Ã˜Â³Ã˜Â§Ã˜Â±: ${order['route']?.toString() ?? 'Ã¢â‚¬â€'}'),
                                                      Text('Ã˜Â§Ã™â€žÃ˜Â³Ã˜Â¹Ã˜Â±: ${NumberFormat('#,##0.00').format(tripOrder.price)} DH'),
                                                      Text('Ã˜Â§Ã™â€žÃ˜ÂªÃ˜Â§Ã˜Â±Ã™Å Ã˜Â®: ${order['departure_date']?.toString() ?? 'Ã¢â‚¬â€'}'),
                                                      Text('Ã˜Â§Ã™â€žÃ˜Â­Ã˜Â§Ã™â€žÃ˜Â©: ${_statusLabel(order['status']?.toString())}'),
                                                      Text('Ã˜Â§Ã™â€žÃ˜Â§Ã˜ÂªÃ˜Â¬Ã˜Â§Ã™â€¡: ${order['direction']?.toString() ?? 'outbound'}'),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ã˜Â¥Ã˜ÂºÃ™â€žÃ˜Â§Ã™â€š')),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _settleTripOrder(order['id'] as int);
                                                    },
                                                    child: const Text('Ã˜ÂªÃ˜Â³Ã™Ë†Ã™Å Ã˜Â©'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      )),
                            ]
                            else ...[
                              const SizedBox.shrink(),
                            ],

                            const SizedBox(height: 28),

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
                                        title: 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡',
                                        value: '$_totalClients',
                                        icon: Icons.people_rounded,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _StatCard(
                                        title: 'Ø£ÙˆØ§Ù…Ø± Ø§Ù„Ø±Ø­Ù„Ø§Øª Ø§Ù„Ù†Ø´Ø·Ø©',
                                        value: '$_activeTripOrders',
                                        icon: Icons.local_shipping_rounded,
                                        color: Theme.of(context).colorScheme.tertiary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _StatCard(
                                        title: 'Ø§Ù„ÙÙˆØ§ØªÙŠØ± Ø§Ù„Ù…Ø³ØªØ­Ù‚Ø©',
                                        value: '$_outstandingInvoices',
                                        icon: Icons.receipt_long_rounded,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _StatCard(
                                        title: 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø¨Ø§Ù„Øº Ø§Ù„Ù…Ø³ØªØ­Ù‚Ø©',
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
                                  label: const Text('Ø¥Ø¯Ø®Ø§Ù„ Ø²Ø¨ÙˆÙ† Ø¬Ø¯ÙŠØ¯'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _openAddInvoiceDialog,
                                  icon: const Icon(Icons.add_card_rounded),
                                  label: const Text('Ø¥Ø¯Ø®Ø§Ù„ ÙØ§ØªÙˆØ±Ø© Ø¬Ø¯ÙŠØ¯Ø©'),
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
                                   label: const Text('Ø¥Ù†Ø´Ø§Ø¡ Ø£Ù…Ø± Ø±Ø­Ù„Ø© Ø¬Ø¯ÙŠØ¯'),
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
                              'Ø£ÙˆØ§Ù…Ø± Ø§Ù„Ø±Ø­Ù„Ø§Øª Ø§Ù„Ø£Ø®ÙŠØ±Ø©',
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
                                  child: Center(child: Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ø£ÙˆØ§Ù…Ø± Ø±Ø­Ù„Ø§Øª')),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: PaginatedDataTable(
                                  columns: const [
                                    DataColumn(label: Text('#')),
                                    DataColumn(label: Text('Ø§Ù„Ø¹Ù…ÙŠÙ„')),
                                    DataColumn(label: Text('Ø§Ù„Ù…Ø³Ø§Ø±')),
                                    DataColumn(label: Text('Ø§Ù„ØªØ§Ø±ÙŠØ®')),
                                    DataColumn(label: Text('Ø§Ù„Ø­Ø§Ù„Ø©')),
                                    DataColumn(label: Text('Ø§Ù„Ø³Ø§Ø¦Ù‚')),
                                    DataColumn(label: Text('Ø¥Ø¬Ø±Ø§Ø¡Ø§Øª')),
                                  ],
                                  source: _TripOrdersDataSource(
                                    tripOrders: _tripOrders,
                                    onView: (order) {
                                      final tripOrder = TripOrder.fromMap(order);
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Ø£Ù…Ø± Ø±Ø­Ù„Ø© #${order['id'] ?? '?'}'),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Ø§Ù„Ø¹Ù…ÙŠÙ„: ${_clientName(order['client_id']?.toString())}'),
                                                Text('Ø§Ù„Ù…Ø³Ø§Ø±: ${order['route']?.toString() ?? 'â€”'}'),
                                                Text('Ø§Ù„Ø³Ø¹Ø±: ${NumberFormat('#,##0.00').format(tripOrder.price)} DH'),
                                                Text('Ø§Ù„ØªØ§Ø±ÙŠØ®: ${order['departure_date']?.toString() ?? 'â€”'}'),
                                                Text('Ø§Ù„Ø­Ø§Ù„Ø©: ${_statusLabel(order['status']?.toString())}'),
                                                Text('Ø§Ù„Ø§ØªØ¬Ø§Ù‡: ${order['direction']?.toString() ?? 'outbound'}'),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ø¥ØºÙ„Ø§Ù‚')),
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
                              'Ø§Ù„ÙÙˆØ§ØªÙŠØ± Ø§Ù„Ø£Ø®ÙŠØ±Ø©',
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
                                  child: Center(child: Text('Ù„Ø§ ØªÙˆØ¬Ø¯ ÙÙˆØ§ØªÙŠØ±')),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: PaginatedDataTable(
                                  columns: const [
                                    DataColumn(label: Text('#')),
                                    DataColumn(label: Text('Ø±Ù‚Ù… Ø§Ù„ÙØ§ØªÙˆØ±Ø©')),
                                    DataColumn(label: Text('Ø§Ù„Ø¹Ù…ÙŠÙ„')),
                                    DataColumn(label: Text('Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ')),
                                    DataColumn(label: Text('Ø§Ù„Ù…Ø¯ÙÙˆØ¹')),
                                    DataColumn(label: Text('Ø§Ù„Ø­Ø§Ù„Ø©')),
                                    DataColumn(label: Text('Ø¥Ø¬Ø±Ø§Ø¡Ø§Øª')),
                                  ],
                                  source: _InvoicesDataSource(
                                    invoices: _invoices,
                                    onView: (invoice) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('ÙØ§ØªÙˆØ±Ø© #${invoice['id'] ?? '?'}'),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Ø±Ù‚Ù… Ø§Ù„ÙØ§ØªÙˆØ±Ø©: ${invoice['invoice_number']?.toString() ?? 'â€”'}'),
                                                Text('Ø§Ù„Ø¹Ù…ÙŠÙ„: ${_clientName(invoice['client_id']?.toString())}'),
                                                Text('Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ: ${NumberFormat('#,##0.00').format((invoice['total_amount'] as num?)?.toDouble() ?? 0.0)} DH'),
                                                Text('Ø§Ù„Ù…Ø¯ÙÙˆØ¹: ${NumberFormat('#,##0.00').format((invoice['paid_amount'] as num?)?.toDouble() ?? 0.0)} DH'),
                                                Text('Ø§Ù„Ø­Ø§Ù„Ø©: ${_statusLabel(invoice['status']?.toString())}'),
                                                Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø¥ØµØ¯Ø§Ø±: ${invoice['issue_date']?.toString() ?? 'â€”'}'),
                                                Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ­Ù‚Ø§Ù‚: ${invoice['due_date']?.toString() ?? 'â€”'}'),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ø¥ØºÙ„Ø§Ù‚')),
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
              )
    );
  }

  Future<void> _openNewTripOrderDialog(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TripFormScreen()),
    );
  }

  Future<void> _openSettlePendingTripDialog(BuildContext context) async {
    final pendingTrips = _tripOrders.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'pending').toList();
    if (pendingTrips.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ø§Ù„Ø±ØªØ¨ Ø§Ù„Ù…ØªØ§Ù†ØŸ ØªØ§Ø«ÙŠ')),
        );
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TripFormScreen()),
    );
  }

  Future<void> _settleTripOrder(int id) async {
    try {
      await _supabase.from('trip_orders').update({'status': 'completed'}).eq('id', id);
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ØªÙ… ØªØ³ÙˆÙŠØ© Ø§Ù„Ø±Ø­Ù„Ø© Ø¨Ù†Ø¬Ø§Ø­')),
        );
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ ØªØ³ÙˆÙŠØ© Ø§Ù„Ø±Ø­Ù„Ø©: $e')),
        );
      }
    }
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
        DataCell(Text('#${order['id']?.toString() ?? 'â€”'}')),
        DataCell(Text(order['client_id']?.toString() ?? 'ØºÙŠØ± Ù…Ø­Ø¯Ø¯')),
        DataCell(Text(order['route']?.toString() ?? 'â€”')),
        DataCell(Text(order['departure_date']?.toString() ?? 'â€”')),
        DataCell(_StatusChip(status: order['status']?.toString())),
        DataCell(Text(order['driver_id']?.toString() ?? 'â€”')),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_rounded, size: 20, color: Colors.blue),
                tooltip: 'Ø¹Ø±Ø¶',
                onPressed: () => onView(order),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                tooltip: 'Ø­Ø°Ù',
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
        DataCell(Text('#${invoice['id']?.toString() ?? 'â€”'}')),
        DataCell(Text(invoice['invoice_number']?.toString() ?? 'â€”')),
        DataCell(Text(invoice['client_id']?.toString() ?? 'ØºÙŠØ± Ù…Ø­Ø¯Ø¯')),
        DataCell(Text('${NumberFormat('#,##0.00').format(totalAmount)} DH')),
        DataCell(Text('${NumberFormat('#,##0.00').format(paidAmount)} DH')),
        DataCell(_StatusChip(status: invoice['status']?.toString())),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_rounded, size: 20, color: Colors.blue),
                tooltip: 'Ø¹Ø±Ø¶',
                onPressed: () => onView(invoice),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                tooltip: 'Ø­Ø°Ù',
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
        return 'Ù†Ø´Ø·';
      case 'pending':
        return 'Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±';
      case 'completed':
        return 'Ù…ÙƒØªÙ…Ù„';
      case 'overdue':
        return 'Ù…ØªØ£Ø®Ø±';
      case 'paid':
        return 'Ù…Ø¯ÙÙˆØ¹';
      case 'partially_paid':
        return 'Ù…Ø¯ÙÙˆØ¹ Ø¬Ø²Ø¦ÙŠØ§Ù‹';
      case 'unpaid':
        return 'ØºÙŠØ± Ù…Ø¯ÙÙˆØ¹';
      default:
        return status ?? 'â€”';
    }
  }
}




