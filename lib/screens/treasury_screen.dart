import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../cubits/treasury_cubit.dart';

// ignore_for_file: use_build_context_synchronously

class TreasuryScreen extends StatelessWidget {
  const TreasuryScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  static const _incomeTypes = <String, String>{
    'trip_revenue': 'تحصيل فواتير الزبائن',
    'capital_injection': 'تزويد رأس مال',
  };
  static const _expenseTypes = <String, String>{
    'office_expense': 'مصاريف عمومية وإدارية',
    'salary': 'رواتب وأجور السائقين',
    'trip_expense': 'وقود/مازوت وصيانة الرحلات',
    'owner_withdrawal': 'سحب صاحب المشروع',
  };
  static const _typeLabels = <String, String>{
    'capital_injection': 'تزويد رأس مال',
    'trip_revenue': 'تحصيل فواتير الزبائن',
    'owner_withdrawal': 'سحب شخصي',
    'office_expense': 'مصاريف عمومية وإدارية',
    'salary': 'رواتب وأجور السائقين',
    'trip_expense': 'وقود/مازوت وصيانة الرحلات',
  };
  static const _currencies = <String, String>{
    'MAD': 'درهم (DH)',
    'EUR': 'يورو (€)',
  };

  static String _currencySymbol(String currency) {
    switch (currency) {
      case 'EUR':
        return '€';
      case 'MAD':
      default:
        return 'DH';
    }
  }

  static bool _isIncomeType(String type) =>
      type == 'capital_injection' || type == 'trip_revenue';

  @override
  Widget build(BuildContext context) {
    return const _TreasuryBody();
  }
}

class _TreasuryBody extends StatelessWidget {
  const _TreasuryBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TreasuryCubit, TreasuryState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<TreasuryCubit>();

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => cubit.refresh(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!state.isBoxesLoading) _buildCashBoxSelector(context, state, cubit),
                  const SizedBox(height: 12),
                  Expanded(child: _buildTransactionList(context, state)),
                ],
              ),
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'add_treasury_tx',
                onPressed: () => _showAddTransactionDialog(context, cubit),
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: const Text('تسجيل حركة صندوق'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                heroTag: 'transfer_cash_box',
                onPressed: () => _showTransferDialog(context, cubit),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('تحويل بين صناديق'),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCashBoxSelector(BuildContext context, TreasuryState state, TreasuryCubit cubit) {
    if (state.cashBoxes.isEmpty) return const SizedBox.shrink();

    final balances = state.boxBalances;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'الصندوق الفرعي',
            ),
            initialValue: state.selectedCashBoxId?.toString(),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('كل الصناديق'),
              ),
              ...state.cashBoxes.map((b) {
                final id = b['id'] as int?;
                final label = b['label']?.toString() ?? b['code']?.toString() ?? '';
                final currencyBalances = balances[id];
                final mad = currencyBalances?['MAD'] ?? 0.0;
                final eur = currencyBalances?['EUR'] ?? 0.0;
                return DropdownMenuItem<String>(
                  value: id?.toString(),
                  child: Text('$label | ${mad.toStringAsFixed(2)} DH | ${eur.toStringAsFixed(2)} €'),
                );
              }),
            ],
            onChanged: (val) => cubit.onCashBoxChanged(val),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'العملة',
          ),
          initialValue: state.selectedCurrency,
          items: TreasuryScreen._currencies.entries
              .map((e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              cubit.onCurrencyChanged(val);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTransactionList(BuildContext context, TreasuryState state) {
    final transactions = state.transactions;

    double totalIncomeMad = 0.0;
    double totalExpenseMad = 0.0;
    double totalIncomeEur = 0.0;
    double totalExpenseEur = 0.0;

    for (final tx in transactions) {
      final double amt = tx.amount;
      final String type = tx.type;
      final String currency = tx.currency;
      final bool isIncome = TreasuryScreen._isIncomeType(type);
      if (currency == 'EUR') {
        if (isIncome) {
          totalIncomeEur += amt;
        } else {
          totalExpenseEur += amt;
        }
      } else {
        if (isIncome) {
          totalIncomeMad += amt;
        } else {
          totalExpenseMad += amt;
        }
      }
    }

    final double netBalanceMad = totalIncomeMad - totalExpenseMad;
    final double netBalanceEur = totalIncomeEur - totalExpenseEur;

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFinanceCard(
                context,
                'رصيد الصندوق الحالي (DH)',
                '${NumberFormat('#,###.00').format(netBalanceMad)} DH',
                Icons.account_balance_rounded,
                netBalanceMad >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFinanceCard(
                context,
                'رصيد الصندوق الحالي (€)',
                '${NumberFormat('#,###.00').format(netBalanceEur)} €',
                Icons.account_balance_rounded,
                netBalanceEur >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFinanceCard(
                context,
                'إيرادات (DH)',
                '${NumberFormat('#,###.00').format(totalIncomeMad)} DH',
                Icons.arrow_upward_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFinanceCard(
                context,
                'مصاريف (DH)',
                '${NumberFormat('#,###.00').format(totalExpenseMad)} DH',
                Icons.arrow_downward_rounded,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFinanceCard(
                context,
                'إيرادات (€)',
                '${NumberFormat('#,###.00').format(totalIncomeEur)} €',
                Icons.arrow_upward_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFinanceCard(
                context,
                'مصاريف (€)',
                '${NumberFormat('#,###.00').format(totalExpenseEur)} €',
                Icons.arrow_downward_rounded,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'كشف حركة الحسابات اليومية والدفق النقدي',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: 'فلترة بالعملة',
              onPressed: () {
                final current = state.selectedCurrency;
                String next;
                if (current == 'ALL') {
                  next = 'MAD';
                } else if (current == 'MAD') {
                  next = 'EUR';
                } else {
                  next = 'ALL';
                }
                context.read<TreasuryCubit>().onCurrencyChanged(next);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (transactions.isEmpty)
          Center(
            child: state.isBoxesLoading
                ? const CircularProgressIndicator()
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Text(
                        'الصندوق فارغ حالياً، لا توجد أي تدفقات مالية مسجلة.'),
                  ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: transactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final String type = tx.type;
                final bool isIncome = TreasuryScreen._isIncomeType(type);
                final double amt = tx.amount;
                final String desc = tx.description.trim();
                final String currency = tx.currency.toUpperCase();
                final String symbol = TreasuryScreen._currencySymbol(currency);

                final DateTime? dt = tx.createdAt;
                final String dateStr = dt != null
                    ? DateFormat('dd/MM/yyyy').format(dt)
                    : '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isIncome
                            ? Colors.green
                            : Colors.red)
                        .withValues(alpha: 0.12),
                    child: Icon(
                      isIncome
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: isIncome
                          ? Colors.green[700]
                          : Colors.red[700],
                      size: 18,
                    ),
                  ),
                  title: Text(
                    desc.isEmpty ? 'عملية بدون بيان' : desc,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${TreasuryScreen._typeLabels[type] ?? type} | $dateStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  trailing: Text(
                    '${isIncome ? '+' : '-'} ${NumberFormat('#,###.00').format(amt)} $symbol',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isIncome
                          ? Colors.green[600]
                          : Colors.red[600],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFinanceCard(BuildContext context, String title, String value, IconData icon, Color color,
      {bool fullWidth = false, double height = 50}) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardWidget = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.fromBorderSide(BorderSide(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        )),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: cardWidget)
        : cardWidget;
  }

  Future<void> _showAddTransactionDialog(BuildContext context, TreasuryCubit cubit) async {
    await showDialog(
      context: context,
      builder: (context) => _AddTransactionDialog(cubit: cubit),
    );
  }

  Future<void> _showTransferDialog(BuildContext context, TreasuryCubit cubit) async {
    await showDialog(
      context: context,
      builder: (context) => _TransferDialog(cubit: cubit),
    );
  }
}

class _AddTransactionDialog extends StatefulWidget {
  const _AddTransactionDialog({required this.cubit});

  final TreasuryCubit cubit;

  @override
  State<_AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<_AddTransactionDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedDirection = 'Expense';
  String _selectedType = 'office_expense';
  String _selectedCurrency = 'MAD';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final state = context.read<TreasuryCubit>().state;
    final categoryMap = _selectedDirection == 'Income'
        ? TreasuryScreen._incomeTypes
        : TreasuryScreen._expenseTypes;
    final formKey = GlobalKey<FormState>();

    return AlertDialog(
      title: const Text('تسجيل حركة مالية في الصندوق',
          textAlign: TextAlign.right),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.cashBoxes.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الصندوق'),
            initialValue: state.selectedCashBoxId?.toString(),
                  items: state.cashBoxes.map((b) {
                    final id = b['id'] as int?;
                    return DropdownMenuItem<String>(
                      value: id?.toString(),
                      child: Text(b['label']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      context.read<TreasuryCubit>().onCashBoxChanged(val),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDirection,
                      decoration:
                          const InputDecoration(labelText: 'نوع العملية'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Expense',
                            child: Text('مصروف / خروج')),
                        DropdownMenuItem(
                            value: 'Income',
                            child: Text('إيراد / دخول')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _selectedDirection = val;
                          _selectedType = (val == 'Income'
                                  ? TreasuryScreen._incomeTypes
                                  : TreasuryScreen._expenseTypes)
                              .keys
                              .first;
                        });
                      },
                      validator: (v) => v == null ? 'يرجى اختيار نوع العملية' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: DropdownButtonFormField<String>(
                      initialValue: _selectedCurrency,
                      decoration:
                          const InputDecoration(labelText: 'العملة'),
                      items: TreasuryScreen._currencies.entries
                          .map((e) => DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCurrency = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration:
                    const InputDecoration(labelText: 'تصنيف الحساب'),
                items: categoryMap.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
                validator: (v) => v == null || v.isEmpty ? 'يرجى اختيار التصنيف' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'البيان / وصف العملية (مثال: شراء قطع غيار)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'يرجى إدخال البيان';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'المبلغ المالي',
                  suffixText: TreasuryScreen._currencySymbol(_selectedCurrency),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                  final p = double.tryParse(v.trim());
                  if (p == null) return 'يرجى إدخال أرقام فقط';
                  if (p <= 0) return 'يرجى إدخال مبلغ أكبر من صفر';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            if (!formKey.currentState!.validate()) return;
            final title = _titleController.text.trim();
            final amountText = _amountController.text.trim();
            final amount = double.tryParse(amountText) ?? 0.0;
            final cashBoxId = state.selectedCashBoxId;

            setState(() => _isLoading = true);
            try {
              await context.read<TreasuryCubit>().addTransaction(
                amount: amount,
                type: _selectedType,
                description: title,
                cashBoxId: cashBoxId,
                currency: _selectedCurrency,
              );
              if (mounted) Navigator.pop(context);
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('خطأ أثناء الحفظ المالي'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedDirection == 'Income'
                ? Colors.green[700]
                : Colors.red[700],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('تثبيت بالصندوق'),
        ),
      ],
    );
  }
}

class _TransferDialog extends StatelessWidget {
  const _TransferDialog({required this.cubit});

  final TreasuryCubit cubit;

  @override
  Widget build(BuildContext context) {
    final amountController = TextEditingController();
    String? fromBoxId;
    String? toBoxId;
    String description = 'تحويل بين الصناديق';
    String transferCurrency = 'MAD';

    final formKey = GlobalKey<FormState>();

    return AlertDialog(
      title: const Text('تحويل بين الصناديق', textAlign: TextAlign.right),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'من صندوق'),
                initialValue: fromBoxId,
                items: context.read<TreasuryCubit>().state.cashBoxes.map((b) {
                  final id = b['id'] as int?;
                  return DropdownMenuItem<String>(
                    value: id?.toString(),
                    child: Text(b['label']?.toString() ?? ''),
                  );
                }).toList(),
                onChanged: (v) => fromBoxId = v,
                validator: (v) => v == null ? 'يرجى اختيار الصندوق المصدر' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'إلى صندوق'),
                initialValue: toBoxId,
                items: context.read<TreasuryCubit>().state.cashBoxes.map((b) {
                  final id = b['id'] as int?;
                  return DropdownMenuItem<String>(
                    value: id?.toString(),
                    child: Text(b['label']?.toString() ?? ''),
                  );
                }).toList(),
                onChanged: (v) => toBoxId = v,
                validator: (v) => v == null ? 'يرجى اختيار الصندوق المستهدف' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: 'المبلغ',
                        suffixText: transferCurrency == 'EUR' ? '€' : TreasuryScreen._currencySymbol(transferCurrency),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                        final p = double.tryParse(v.trim());
                        if (p == null) return 'أرقام فقط';
                        if (p <= 0) return 'المبلغ يجب أن يكون أكبر من صفر';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: transferCurrency,
                      decoration: const InputDecoration(labelText: 'العملة'),
                      items: TreasuryScreen._currencies.entries
                          .map((e) => DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          transferCurrency = val;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'البيان'),
                onChanged: (v) => description = v,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final amount = double.tryParse(amountController.text.trim()) ?? 0;
            try {
              await context.read<TreasuryCubit>().addTransfer(
                amount: amount,
                fromCashBoxId: int.parse(fromBoxId!),
                toCashBoxId: int.parse(toBoxId!),
                description: description,
                currency: transferCurrency,
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فشل التحويل'), backgroundColor: Colors.red),
                );
              }
            }
          },
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}
