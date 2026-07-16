import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../l10n/locale_provider.dart';
import '../widgets/role_guard.dart';

// ignore_for_file: use_build_context_synchronously

/// شاشة إدارة الحسابات البنكية — للأدمن فقط.
/// تعرض قائمة بالحسابات البنكية (مع شارة العملة DH / €) وتتيح الإضافة
/// والتعديل والحذف عبر نموذج حوار. الوصول مقيد بصلاحية الأدمن عبر [RoleGuard].
class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  /// م helper ثنائي اللغة: العربية افتراضياً، الفرنسية عند اختيار اللغة الفرنسية.
  String _t(String ar, String fr) {
    final code =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    return code == 'fr' ? fr : ar;
  }

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final accounts = await _supabaseService.getBankAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  /// شارة العملة: MAD = DH، EUR = €.
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

  Future<void> _openAccountDialog({Map<String, dynamic>? account}) async {
    final isEdit = account != null;

    final bankNameController =
        TextEditingController(text: account?['bank_name']?.toString() ?? '');
    final accountNumberController =
        TextEditingController(text: account?['account_number']?.toString() ?? '');
    final accountHolderController =
        TextEditingController(text: account?['account_holder']?.toString() ?? '');
    final ibanController =
        TextEditingController(text: account?['iban']?.toString() ?? '');
    final swiftController =
        TextEditingController(text: account?['swift_code']?.toString() ?? '');
    String currency = account?['currency']?.toString() ?? 'MAD';
    bool isActive = account?['is_active'] as bool? ?? true;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: Localizations.localeOf(dialogContext).languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: AlertDialog(
            title: Text(_t('إضافة حساب بنكي', 'Ajouter un compte bancaire')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: bankNameController,
                    decoration: InputDecoration(
                      labelText: _t('اسم البنك', 'Nom de la banque'),
                    ),
                  ),
                  TextFormField(
                    controller: accountNumberController,
                    decoration: InputDecoration(
                      labelText: _t('رقم الحساب', 'Numéro de compte'),
                    ),
                  ),
                  TextFormField(
                    controller: accountHolderController,
                    decoration: InputDecoration(
                      labelText: _t('صاحب الحساب', 'Titulaire du compte'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: InputDecoration(
                      labelText: _t('العملة', 'Devise'),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MAD', child: Text('MAD (DH)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => currency = value);
                    },
                  ),
                  TextFormField(
                    controller: ibanController,
                    decoration: InputDecoration(
                      labelText: _t('IBAN', 'IBAN'),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  TextFormField(
                    controller: swiftController,
                    decoration: InputDecoration(
                      labelText: _t('رمز SWIFT', 'Code SWIFT'),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_t('حساب نشط', 'Compte actif')),
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('إلغاء', 'Annuler')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final bankName = bankNameController.text.trim();
                  final accountNumber = accountNumberController.text.trim();
                  final accountHolder = accountHolderController.text.trim();

                  if (bankName.isEmpty || accountNumber.isEmpty || accountHolder.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _t('يرجى تعبئة الحقول الإجبارية',
                              'Veuillez remplir les champs obligatoires'),
                        ),
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
                    if (isEdit) {
                      await _supabaseService.updateBankAccount(
                        account['id'] as String,
                        data,
                        localRow: account,
                      );
                    } else {
                      await _supabaseService.addBankAccount(data);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _loadAccounts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? _t('تم تحديث الحساب بنجاح',
                                  'Compte mis à jour avec succès')
                              : _t('تمت إضافة الحساب بنجاح',
                                  'Compte ajouté avec succès'),
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _t('خطأ في حفظ الحساب: {0}',
                              'Erreur lors de l\'enregistrement : {0}')
                              .replaceAll('{0}', e.toString()),
                        ),
                      ),
                    );
                  }
                },
                child: Text(_t('حفظ', 'Enregistrer')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: Localizations.localeOf(dialogContext).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: AlertDialog(
          title: Text(_t('تأكيد الحذف', 'Confirmer la suppression')),
          content: Text(
            _t('هل أنت متأكد من حذف هذا الحساب البنكي؟',
                'Êtes-vous sûr de vouloir supprimer ce compte bancaire ?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('إلغاء', 'Annuler')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('حذف', 'Supprimer')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabaseService.deleteBankAccount(account['id'] as String);
      if (!mounted) return;
      await _loadAccounts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('تم حذف الحساب بنجاح', 'Compte supprimé avec succès'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('خطأ في حذف الحساب: {0}', 'Erreur lors de la suppression : {0}')
                .replaceAll('{0}', e.toString()),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['admin'],
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _t('إدارة الحسابات البنكية', 'Gestion des comptes bancaires'),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAccountDialog(),
          tooltip: _t('إضافة حساب بنكي', 'Ajouter un compte bancaire'),
          child: const Icon(Icons.add),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _accounts.isEmpty
                ? Center(
                    child: Text(
                      _t('لا يوجد حسابات بنكية حالياً',
                          'Aucun compte bancaire actuellement'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      final currency =
                          account['currency']?.toString() ?? 'MAD';
                      final iban = account['iban']?.toString() ?? '';
                      final holder = account['account_holder']?.toString() ?? '';
                      final isActive = account['is_active'] as bool? ?? true;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.account_balance, color: Colors.blue),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  account['bank_name']?.toString() ??
                                      _t('بدون اسم', 'Sans nom'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _currencyBadge(currency),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_t('الحساب', 'Compte')}: ${account['account_number'] ?? ''}'
                                '${holder.isNotEmpty ? ' • $holder' : ''}',
                              ),
                              if (iban.isNotEmpty)
                                Text('IBAN: $iban'),
                              if (!isActive)
                                Text(
                                  _t('غير نشط', 'Inactif'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: _t('تعديل', 'Modifier'),
                                onPressed: () => _openAccountDialog(account: account),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                tooltip: _t('حذف', 'Supprimer'),
                                onPressed: () => _confirmDelete(account),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
