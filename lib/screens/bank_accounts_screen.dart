import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../cubits/bank_accounts_cubit.dart';
import '../repositories/bank_account_repository.dart';
import '../l10n/locale_provider.dart';

// ignore_for_file: use_build_context_synchronously

class BankAccountsScreen extends StatelessWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BankAccountsCubit(
        context.read<BankAccountRepository>(),
      ),
      child: const _BankAccountsScreenBody(),
    );
  }
}

class _BankAccountsScreenBody extends StatelessWidget {
  const _BankAccountsScreenBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BankAccountsCubit, BankAccountsState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<BankAccountsCubit>();
        final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

        String t(String ar, String fr) {
          final code = localeProvider.locale.languageCode;
          return code == 'fr' ? fr : ar;
        }

        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(t('الحسابات البنكية', 'Comptes bancaires')),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _openAccountDialog(context, cubit, t: t),
                tooltip: t('إضافة حساب', 'Ajouter un compte'),
              ),
            ],
          ),
          body: state.accounts.isEmpty
              ? const Center(child: Text('لا توجد حسابات بنكية حالياً'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.accounts.length,
                  itemBuilder: (context, index) {
                    final account = state.accounts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.account_balance, color: Colors.blue),
                        title: Text(account.bankName),
                        subtitle: Text(
                          '${account.accountNumber} • ${account.accountHolder}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _currencyBadge(account.currency),
                            if (account.cashBoxId != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(Icons.account_balance_wallet, size: 16),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _currencyBadge(String currency) {
    final isMad = currency == 'MAD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMad ? Colors.green : Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isMad ? 'DH' : '€',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

Future<void> _openAccountDialog(
  BuildContext context,
  BankAccountsCubit cubit, {
  required String Function(String ar, String fr) t,
}) async {
  final bankNameController = TextEditingController();
  final accountNumberController = TextEditingController();
  final accountHolderController = TextEditingController();
  final ibanController = TextEditingController();
  final swiftController = TextEditingController();
  String currency = 'MAD';
  bool isActive = true;

  await showDialog(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: Localizations.localeOf(dialogContext).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: AlertDialog(
        title: Text(t('إضافة حساب بنكي', 'Ajouter un compte bancaire')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: bankNameController,
                decoration: InputDecoration(labelText: t('اسم البنك', 'Nom de la banque')),
              ),
              TextFormField(
                controller: accountNumberController,
                decoration: InputDecoration(labelText: t('رقم الحساب', 'Numéro de compte')),
              ),
              TextFormField(
                controller: accountHolderController,
                decoration: InputDecoration(labelText: t('صاحب الحساب', 'Titulaire du compte')),
              ),
              DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: InputDecoration(labelText: t('العملة', 'Devise')),
                items: const [
                  DropdownMenuItem(value: 'MAD', child: Text('MAD (DH)')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                ],
                onChanged: (value) {
                  if (value != null) currency = value;
                },
              ),
              TextFormField(
                controller: ibanController,
                decoration: InputDecoration(labelText: t('IBAN', 'IBAN')),
                textCapitalization: TextCapitalization.characters,
              ),
              TextFormField(
                controller: swiftController,
                decoration: InputDecoration(labelText: t('رمز SWIFT', 'Code SWIFT')),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('إلغاء', 'Annuler')),
          ),
          ElevatedButton(
            onPressed: () async {
              final bankName = bankNameController.text.trim();
              final accountNumber = accountNumberController.text.trim();
              final accountHolder = accountHolderController.text.trim();

              if (bankName.isEmpty || accountNumber.isEmpty || accountHolder.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('يرجى تعبئة الحقول الإجبارية', 'Veuillez remplir les champs obligatoires')),
                  ),
                );
                return;
              }

              final data = {
                'bank_name': bankName,
                'account_number': accountNumber,
                'account_holder': accountHolder,
                'currency': currency,
                'iban': ibanController.text.trim(),
                'swift_code': swiftController.text.trim(),
                'is_active': isActive,
              };
              try {
                await cubit.addAccount(data);
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t('خطأ في حفظ الحساب', 'Erreur lors de l\'enregistrement')
                          .replaceAll('{0}', e.toString()),
                    ),
                  ),
                );
              }
            },
            child: Text(t('حفظ', 'Enregistrer')),
          ),
        ],
      ),
    ),
  );
}