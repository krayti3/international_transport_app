import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../widgets/language_switcher.dart';
import '../widgets/responsive_layout.dart';

// ignore_for_file: use_build_context_synchronously

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();

  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneMaController = TextEditingController();
  final _phoneEuController = TextEditingController();
  final _bankAccountMaController = TextEditingController();
  final _bankAccountEuController = TextEditingController();
  final _invoiceDescController = TextEditingController();
  final _defaultCurrencyController = TextEditingController();
  final _companyCountryController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  String? _logoUrl;
  Uint8List? _logoBytes;
  bool _tvaEnabled = true;
  double _tvaPercentage = 20.0;
  final _tvaPercentageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneMaController.dispose();
    _phoneEuController.dispose();
    _bankAccountMaController.dispose();
    _bankAccountEuController.dispose();
    _invoiceDescController.dispose();
    _defaultCurrencyController.dispose();
    _companyCountryController.dispose();
    _tvaPercentageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _supabaseService.getSystemSettings(),
        _supabaseService.getAppSettings(),
      ]);
      final Map<String, dynamic>? sysSettings = results[0] as Map<String, dynamic>?;
      final Map<String, dynamic>? appSettings = results[1] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _companyNameController.text = sysSettings?['company_name']?.toString() ?? '';
        _addressController.text = sysSettings?['head_office_address']?.toString() ?? '';
        _emailController.text = sysSettings?['contact_email']?.toString() ?? '';
        _phoneMaController.text = sysSettings?['phone_ma']?.toString() ?? '';
        _phoneEuController.text = sysSettings?['phone_eu']?.toString() ?? '';
        _bankAccountMaController.text = sysSettings?['bank_account_ma']?.toString() ?? '';
        _bankAccountEuController.text = sysSettings?['bank_account_eu']?.toString() ?? '';
        _invoiceDescController.text = sysSettings?['invoice_description']?.toString() ?? '';
        _logoUrl = sysSettings?['logo_url']?.toString();
        _defaultCurrencyController.text = sysSettings?['default_currency']?.toString() ?? 'MAD';
        _companyCountryController.text = sysSettings?['company_country']?.toString() ?? 'Maroc';
        _tvaEnabled = appSettings?['is_enabled'] as bool? ?? true;
        _tvaPercentage = (appSettings?['percentage'] as num?)?.toDouble() ?? 20.0;
        _tvaPercentageController.text = _tvaPercentage.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadLogo(ImageSource source) async {
    setState(() => _isUploadingLogo = true);
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) {
        setState(() => _isUploadingLogo = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final url = await _supabaseService.uploadCompanyLogo(picked.name, bytes);
      setState(() {
        _logoBytes = bytes;
        _logoUrl = url;
        _isUploadingLogo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingLogo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الشعار: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveSettings() async {
    final data = <String, dynamic>{
      'company_name': _companyNameController.text.trim(),
      'head_office_address': _addressController.text.trim(),
      'contact_email': _emailController.text.trim(),
      'phone_ma': _phoneMaController.text.trim(),
      'phone_eu': _phoneEuController.text.trim(),
      'bank_account_ma': _bankAccountMaController.text.trim(),
      'bank_account_eu': _bankAccountEuController.text.trim(),
      'invoice_description': _invoiceDescController.text.trim(),
      'default_currency': _defaultCurrencyController.text.trim().toUpperCase(),
      'company_country': _companyCountryController.text.trim(),
      'logo_url': _logoUrl ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };

    setState(() => _isSaving = true);
    try {
      await _supabaseService.updateSystemSettings(data);
      await _supabaseService.updateAppSettings(
        _tvaEnabled,
        Decimal.parse(_tvaPercentage.toStringAsFixed(2)).toDouble(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات النظام بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الشركة'),
        actions: const [
          LanguageSwitcher(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AppConstrained(
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ التغييرات'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colorScheme.primary, width: 2),
                                      image: _logoBytes != null
                                          ? DecorationImage(
                                              image: MemoryImage(_logoBytes!),
                                              fit: BoxFit.cover,
                                            )
                                          : _logoUrl != null && _logoUrl!.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(_logoUrl!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                      color: _logoBytes == null && (_logoUrl == null || _logoUrl!.isEmpty)
                                          ? colorScheme.surfaceContainerHighest
                                          : null,
                                    ),
                                    child: _logoBytes == null && (_logoUrl == null || _logoUrl!.isEmpty)
                                        ? Icon(Icons.business_rounded, size: 40, color: colorScheme.onSurfaceVariant)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: _isUploadingLogo
                                          ? null
                                          : () {
                                              showModalBottomSheet(
                                                context: context,
                                                builder: (context) => SafeArea(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      ListTile(
                                                        leading: const Icon(Icons.photo_library_rounded),
                                                        title: const Text('اختر من المعرض'),
                                                        onTap: () {
                                                          Navigator.pop(context);
                                                          _pickAndUploadLogo(ImageSource.gallery);
                                                        },
                                                      ),
                                                      ListTile(
                                                        leading: const Icon(Icons.camera_alt_rounded),
                                                        title: const Text('التقاط صورة بالكاميرا'),
                                                        onTap: () {
                                                          Navigator.pop(context);
                                                          _pickAndUploadLogo(ImageSource.camera);
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: _isUploadingLogo
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : Icon(Icons.edit_rounded, size: 18, color: colorScheme.onPrimary),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'شعار الشركة',
                                style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionCard(
                          title: 'الهوية',
                          icon: Icons.business_rounded,
                          children: [
                            TextFormField(
                              controller: _companyNameController,
                              decoration: InputDecoration(
                                labelText: 'اسم الشركة',
                                prefixIcon: const Icon(Icons.business_rounded),
                                border: const OutlineInputBorder(),
                              ),
                              enabled: !_isSaving,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'عنوان المقر الرئيسي',
                                prefixIcon: const Icon(Icons.location_on_rounded),
                                border: const OutlineInputBorder(),
                              ),
                              enabled: !_isSaving,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'إيميل المراسلات',
                                prefixIcon: const Icon(Icons.email_rounded),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_isSaving,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'الإعدادات الافتراضية',
                          icon: Icons.tune_rounded,
                          children: [
                            TextFormField(
                              controller: _defaultCurrencyController,
                              decoration: InputDecoration(
                                labelText: 'العملة الافتراضية (MAD / EUR)',
                                prefixIcon: const Icon(Icons.payments_rounded),
                                border: const OutlineInputBorder(),
                              ),
                              enabled: !_isSaving,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _companyCountryController,
                              decoration: InputDecoration(
                                labelText: 'بلد الشركة الافتراضي',
                                prefixIcon: const Icon(Icons.public_rounded),
                                border: const OutlineInputBorder(),
                              ),
                              enabled: !_isSaving,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'الاتصال الدولي',
                          icon: Icons.public_rounded,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneMaController,
                                    decoration: InputDecoration(
                                      labelText: 'الهاتف المغربي',
                                      prefixIcon: const Icon(Icons.phone_rounded),
                                      border: const OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    enabled: !_isSaving,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneEuController,
                                    decoration: InputDecoration(
                                      labelText: 'الهاتف الأوروبي',
                                      prefixIcon: const Icon(Icons.phone_in_talk_rounded),
                                      border: const OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    enabled: !_isSaving,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'الحسابات البنكية',
                          icon: Icons.account_balance_rounded,
                          children: [
                              Column(
                                children: [
                                  TextFormField(
                                    controller: _bankAccountMaController,
                                    decoration: InputDecoration(
                                      labelText: 'الحساب المغربي الافتراضي',
                                      prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                                      border: const OutlineInputBorder(),
                                    ),
                                    enabled: !_isSaving,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _bankAccountEuController,
                                    decoration: InputDecoration(
                                      labelText: 'الحساب الأوروبي الافتراضي',
                                      prefixIcon: const Icon(Icons.euro_rounded),
                                      border: const OutlineInputBorder(),
                                    ),
                                    enabled: !_isSaving,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'تذييل الفاتورة',
                          icon: Icons.description_rounded,
                          children: [
                            TextFormField(
                              controller: _invoiceDescController,
                              decoration: InputDecoration(
                                labelText: 'الوصف أسفل الفاتورة (descr facture)',
                                prefixIcon: const Icon(Icons.text_fields_rounded),
                                border: const OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 5,
                              enabled: !_isSaving,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'إعدادات الـ TVA',
                          icon: Icons.account_balance_rounded,
                          children: [
                            SwitchListTile(
                              title: const Text('تفعيل الـ TVA'),
                              subtitle: Text(_tvaEnabled ? 'مفعل' : 'معطل'),
                              value: _tvaEnabled,
                              onChanged: (val) => setState(() => _tvaEnabled = val),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _tvaPercentageController,
                              decoration: InputDecoration(
                                labelText: 'نسبة الـ TVA (%)',
                                prefixIcon: const Icon(Icons.percent_rounded),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              enabled: !_isSaving && _tvaEnabled,
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) {
                                  setState(() => _tvaPercentage = parsed);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
