import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/language_switcher.dart';
import '../widgets/responsive_layout.dart';

// ignore_for_file: use_build_context_synchronously

/// شاشة إعدادات النظام — تظهر فقط لحساب الأدمن.
///
/// تقرأ السطر الوحيد من جدول [app_settings] (id = 1) وتتيح تعديل:
///  * تفعيل/إلغاء الـ TVA ([is_tva_enabled]).
///  * نسبة الـ TVA ([percentage]).
/// عند الحفظ تُحدّث السطر مباشرة عبر [SupabaseService.updateAppSettings].
class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _isTvaEnabled = false;
  final TextEditingController _tvaPercentageController = TextEditingController(text: '20');
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _tvaPercentageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await _supabaseService.getAppSettings();
    if (!mounted) return;
    setState(() {
      _isTvaEnabled = settings?['is_enabled'] as bool? ?? false;
      final pct = (settings?['percentage'] as num?)?.toDouble() ?? 20.0;
      _tvaPercentageController.text = pct.toString();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final parsed = double.tryParse(_tvaPercentageController.text.trim());
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال نسبة TVA صحيحة (رقم موجب)')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _supabaseService.updateAppSettings(_isTvaEnabled, parsed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات النظام بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام'),
        actions: const [
          LanguageSwitcher(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AppConstrained(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إعدادات الضريبة (TVA)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'تفعيل الـ TVA',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              Switch(
                                value: _isTvaEnabled,
                                onChanged: _isSaving
                                    ? null
                                    : (value) => setState(() => _isTvaEnabled = value),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tvaPercentageController,
                            decoration: const InputDecoration(
                              labelText: 'نسبة الـ TVA (%)',
                              border: OutlineInputBorder(),
                              suffixText: '%',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: !_isSaving,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'تُطبَّق هذه النسبة تلقائياً عند إصدار الفواتير إذا كان التفعيل مُفعل.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveSettings,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
