import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class CashBoxLedgerScreen extends StatefulWidget {
  const CashBoxLedgerScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<CashBoxLedgerScreen> createState() => _CashBoxLedgerScreenState();
}

class _CashBoxLedgerScreenState extends State<CashBoxLedgerScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _cashBoxes = [];
  List<Map<String, dynamic>> _transactions = [];
  String? _selectedCashBoxId;
  String _selectedCurrency = 'MAD';
  bool _isLoading = true;

  static const _currencies = <String, String>{
    'MAD': 'الدرهم (DH)',
    'EUR': 'اليورو (€)',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _currencySymbol(String currency) {
    switch (currency) {
      case 'EUR':
        return '€';
      case 'MAD':
      default:
        return 'DH';
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final boxes = await _supabaseService.getCashBoxes();
    if (!mounted) return;
    setState(() {
      _cashBoxes = boxes;
      _isLoading = false;
    });
    await _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    int? cashBoxId;
    if (_selectedCashBoxId != null && _selectedCashBoxId != 'all') {
      cashBoxId = int.tryParse(_selectedCashBoxId!);
    }
    final txs = await _supabaseService.getTreasuryTransactions(cashBoxId: cashBoxId);
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _isLoading = false;
    });
  }

  Future<void> _onCashBoxChanged(String? value) async {
    setState(() => _selectedCashBoxId = value);
    await _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = _currencySymbol(_selectedCurrency);
    final filteredTransactions = _selectedCurrency == 'ALL'
        ? _transactions
        : _transactions.where((t) {
            final c = (t['currency']?.toString() ?? 'MAD').toUpperCase();
            return c == _selectedCurrency;
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حركة الصندوق'),
        actions: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'العملة',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            initialValue: _selectedCurrency,
            items: [
              const DropdownMenuItem<String>(
                value: 'ALL',
                child: Text('الكل'),
              ),
              ..._currencies.entries.map((e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  )),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedCurrency = val);
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'اختر الصندوق',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      initialValue: _selectedCashBoxId,
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('كل الصناديق'),
                        ),
                        ..._cashBoxes.map((b) {
                          final id = b['id']?.toString() ?? '';
                          final label = b['label']?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(label),
                          );
                        }),
                      ],
                      onChanged: _onCashBoxChanged,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(theme.colorScheme.primaryContainer),
                          columns: const [
                            DataColumn(label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('العمليات', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('مدين (صادر)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('داخل (وارد)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('الرصيد', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _buildLedgerRows(filteredTransactions, currencySymbol),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<DataRow> _buildLedgerRows(List<Map<String, dynamic>> transactions, String currencySymbol) {
    final rows = <DataRow>[];
    double runningBalance = 0.0;

    if (transactions.isEmpty) {
      return [
        DataRow(cells: [
          const DataCell(Text('-')),
          const DataCell(Text('لا توجد حركات')),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
        ]),
      ];
    }

    final typeLabels = <String, String>{
      'capital_injection': 'تزويد رأس مال',
      'trip_revenue': 'تحصيل فواتير الزبائن',
      'owner_withdrawal': 'سحب صاحب المشروع',
      'office_expense': 'مصاريف عمومية وإدارية',
      'salary': 'رواتب وأجور السائقين',
      'trip_expense': 'وقود/مازوت وصيانة الرحلات',
      'transfer': 'تحويل بين الصناديق',
    };

    for (final tx in transactions) {
      final double amt = (tx['amount'] ?? 0.0).toDouble();
      final String type = (tx['type'] ?? '').toString();
      final String desc = (tx['description'] ?? '').toString().trim();
      final String currency = (tx['currency']?.toString() ?? 'MAD').toUpperCase();
      final String txSymbol = _currencySymbol(currency);
      final String label = typeLabels[type] ?? type;
      final String operationText = desc.isNotEmpty ? '$label - $desc' : label;

      final DateTime? dt = DateTime.tryParse(tx['created_at']?.toString() ?? '');
      final String dateStr = dt != null
          ? DateFormat('dd/MM/yyyy').format(dt)
          : (tx['created_at']?.toString() ?? '');

      final isIncome = type == 'capital_injection' || type == 'trip_revenue';
      final isTransferOut = type == 'transfer' && _isTransferOut(tx);

      double debit = 0.0;
      double credit = 0.0;

      if (isIncome) {
        credit = amt;
        runningBalance += amt;
      } else if (type == 'transfer') {
        if (isTransferOut) {
          debit = amt;
          runningBalance -= amt;
        } else {
          credit = amt;
          runningBalance += amt;
        }
      } else {
        debit = amt;
        runningBalance -= amt;
      }

      final displayDebit = _selectedCurrency == 'ALL' && currency != _selectedCurrency
          ? '-'
          : (debit > 0 ? '${NumberFormat('#,###.00').format(debit)} $txSymbol' : '-');
      final displayCredit = _selectedCurrency == 'ALL' && currency != _selectedCurrency
          ? '-'
          : (credit > 0 ? '${NumberFormat('#,###.00').format(credit)} $txSymbol' : '-');

      rows.add(DataRow(
        cells: [
          DataCell(Text(dateStr)),
          DataCell(Text(operationText, overflow: TextOverflow.ellipsis)),
          DataCell(Text(displayDebit, style: const TextStyle(color: Colors.red))),
          DataCell(Text(displayCredit, style: const TextStyle(color: Colors.green))),
          DataCell(Text(
            '${runningBalance >= 0 ? '+' : ''}${NumberFormat('#,###.00').format(runningBalance)} $currencySymbol',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: runningBalance >= 0 ? Colors.green : Colors.red,
            ),
          )),
        ],
      ));
    }

    return rows;
  }

  bool _isTransferOut(Map<String, dynamic> tx) {
    final cashBoxId = _selectedCashBoxId;
    if (cashBoxId == null || cashBoxId == 'all') return false;
    final txFrom = tx['cash_box_id'];
    final fromId = int.tryParse(cashBoxId);
    if (fromId == null || txFrom == null) return false;
    return txFrom == fromId;
  }
}
