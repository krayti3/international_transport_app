import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:decimal/decimal.dart';
import 'package:collection/collection.dart';
import '../models/client.dart';
import '../models/bank_account.dart';
import '../providers/invoice_provider.dart';
import '../services/client_service.dart';
import '../services/settings_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/date_wheel_picker.dart';

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClientService _clientService = ClientService();
  final SettingsService _settingsService = SettingsService();

  Client? _selectedClient;
  String? _selectedBankAccountType;
  final _bankAccountTypeFieldKey = GlobalKey<FormFieldState<String?>>();
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  final _htAmountController = TextEditingController();
  final _ttcAmountController = TextEditingController();
  final _tvaRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      _tvaRateController.text = invoiceProvider.tvaRate.toString();
      _htAmountController.addListener(() {
        if (invoiceProvider.inputMode == 'HT') {
          invoiceProvider.setInputAmount(Decimal.tryParse(_htAmountController.text) ?? Decimal.zero);
        }
      });
      _ttcAmountController.addListener(() {
        if (invoiceProvider.inputMode == 'TTC') {
          invoiceProvider.setInputAmount(Decimal.tryParse(_ttcAmountController.text) ?? Decimal.zero);
        }
      });
    });
  }

  @override
  void dispose() {
    _htAmountController.dispose();
    _ttcAmountController.dispose();
    _tvaRateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, {required bool isIssueDate}) async {
    final DateTime? picked = await showDateWheelPicker(
      context: context,
      initialDate: isIssueDate ? _issueDate : _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != (isIssueDate ? _issueDate : _dueDate)) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);

    // Update controllers when calculation changes
    if (invoiceProvider.calculation != null) {
      if (invoiceProvider.inputMode == 'HT') {
        _ttcAmountController.text = invoiceProvider.calculation!.ttcAmount.toStringAsFixed(2);
      } else {
        _htAmountController.text = invoiceProvider.calculation!.htAmount.toStringAsFixed(2);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('إنشاء فاتورة جديدة')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClientSelector(),
              const SizedBox(height: 16),
              _buildBankAccountsSelector(),
              const SizedBox(height: 16),
              _buildBankAccountTypeSelector(),
              const SizedBox(height: 16),
              _buildPaymentAccountSummary(),
              const SizedBox(height: 16),
              _buildDatePickers(),
              const SizedBox(height: 16),
              _buildInputModeToggle(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildHtAmountField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTtcAmountField()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTvaRateField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTvaAmountField()),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: Text(context.tr('حفظ الفاتورة')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientSelector() {
    return FutureBuilder<List<Client>>(
      future: _clientService.getClients(activeOnly: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final clients = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Client>(
              initialValue: _selectedClient,
              decoration: InputDecoration(labelText: context.tr('الزبون')),
              items: clients
                  .toList()
                  .sorted((a, b) => a.name.compareTo(b.name))
                  .map((client) {
                    return DropdownMenuItem<Client>(
                      value: client,
                      child: Text(client.name),
                    );
                  }).toList(),
              onChanged: (client) {
                setState(() {
                  _selectedClient = client;
                  if (client?.defaultBankAccount != null) {
                    _selectedBankAccountType = client!.defaultBankAccount;
                  } else if (client?.defaultBankAccountId == 'moroccan' || client?.defaultBankAccountId == 'european') {
                    _selectedBankAccountType = client!.defaultBankAccountId;
                  } else {
                    _selectedBankAccountType = 'moroccan';
                  }
                  _bankAccountTypeFieldKey.currentState?.didChange(_selectedBankAccountType);
                });
              },
              validator: (value) => value == null ? context.tr('يرجى اختيار زبون') : null,
            ),
            if (_selectedClient?.lastInvoiceNumber != null &&
                _selectedClient!.lastInvoiceNumber!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, right: 16.0),
                child: Text(
                  'آخر فاتورة: ${_selectedClient!.lastInvoiceNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBankAccountsSelector() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    return FutureBuilder<List<BankAccount>>(
      future: _clientService.getBankAccounts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final accounts = snapshot.data ?? [];
        return DropdownButtonFormField<BankAccount>(
          initialValue: invoiceProvider.selectedBankAccount,
          decoration: InputDecoration(labelText: context.tr('الحساب البنكي')),
          items: accounts
              .toList()
              .sorted((a, b) => a.displayName.compareTo(b.displayName))
              .map((account) {
                return DropdownMenuItem<BankAccount>(
                  value: account,
                  child: Text(account.displayName),
                );
              }).toList(),
          onChanged: (account) {
            invoiceProvider.setBankAccount(account);
          },
          validator: (value) => null,
        );
      },
    );
  }

  Widget _buildBankAccountTypeSelector() {
    return DropdownButtonFormField<String>(
      key: _bankAccountTypeFieldKey,
      decoration: InputDecoration(labelText: 'نوع الحساب البنكي', border: const OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'moroccan', child: Text('🇲🇦 الحساب المغربي (MAD)')),
        DropdownMenuItem(value: 'european', child: Text('🇪🇺 الحساب الأوروبي (EUR)')),
      ],
      onChanged: (val) {
        setState(() {
          _selectedBankAccountType = val;
        });
      },
      validator: (value) => value == null ? 'يرجى اختيار نوع الحساب البنكي' : null,
    );
  }

  Widget _buildPaymentAccountSummary() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final bankAccount = invoiceProvider.selectedBankAccount;
    final bankType = _selectedBankAccountType;
    final client = _selectedClient;

    if (bankAccount == null && bankType == null && client != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'لم يتم تحديد حساب بنكي. سيتم استخدام الإعدادات الافتراضية للزبون.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    String summary = '';
    if (bankAccount != null) {
      summary = 'الحساب البنكي المحدد: ${bankAccount.displayName}';
    } else if (bankType != null) {
      final typeLabel = bankType == 'moroccan' ? 'الحساب المغربي (MAD)' : 'الحساب الأوروبي (EUR)';
      summary = 'نوع الحساب: $typeLabel';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickers() {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            title: Text(context.tr('تاريخ الإصدار')),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(_issueDate), textDirection: TextDirection.ltr),
            onTap: () => _selectDate(context, isIssueDate: true),
          ),
        ),
        Expanded(
          child: ListTile(
            title: Text(context.tr('تاريخ الاستحقاق')),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(_dueDate), textDirection: TextDirection.ltr),
            onTap: () => _selectDate(context, isIssueDate: false),
          ),
        ),
      ],
    );
  }

  Widget _buildInputModeToggle() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'HT', label: Text(context.tr('HT'))),
        ButtonSegment(value: 'TTC', label: Text(context.tr('TTC'))),
      ],
      selected: {invoiceProvider.inputMode},
      onSelectionChanged: (newSelection) {
        invoiceProvider.setInputMode(newSelection.first);
      },
    );
  }

  Widget _buildHtAmountField() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    return TextFormField(
      controller: _htAmountController,
      decoration: InputDecoration(labelText: context.tr('المبلغ HT')),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      readOnly: invoiceProvider.inputMode == 'TTC',
    );
  }

  Widget _buildTtcAmountField() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    return TextFormField(
      controller: _ttcAmountController,
      decoration: InputDecoration(labelText: context.tr('المبلغ TTC')),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      readOnly: invoiceProvider.inputMode == 'HT',
    );
  }

  Widget _buildTvaRateField() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    return TextFormField(
      controller: _tvaRateController,
      decoration: InputDecoration(labelText: context.tr('نسبة TVA (%)')),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        invoiceProvider.setTvaRate(Decimal.tryParse(value) ?? Decimal.zero);
      },
    );
  }

  Widget _buildTvaAmountField() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    return TextFormField(
      decoration: InputDecoration(labelText: context.tr('مبلغ TVA')),
      readOnly: true,
      controller: TextEditingController(
        text: invoiceProvider.calculation?.tvaAmount.toStringAsFixed(2) ?? '0.00',
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      final amount = invoiceProvider.inputAmount;
      if (amount <= Decimal.zero) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('الرجاء إدخال مبلغ صحيح'))),
        );
        return;
      }

      try {
        final newInvoice = await _settingsService.createInvoice(
          clientId: _selectedClient!.id!,
          amount: amount,
          inputMode: invoiceProvider.inputMode,
          bankAccountId: invoiceProvider.selectedBankAccount?.id,
          bankAccountType: _selectedBankAccountType ?? _bankAccountTypeFieldKey.currentState?.value,
          bankInfoText: null,
          issueDate: _issueDate,
          dueDate: _dueDate,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('تم إنشاء الفاتورة بنجاح'))),
        );
        Navigator.pop(context, newInvoice);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('خطأ في إنشاء الفاتورة: {0}', [e.toString()]))),
        );
      }
    }
  }
}
