import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/services/calculation_engine.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/models/invoice.dart';

class SettingsService {
  final SupabaseClient supabase = Supabase.instance.client;

  String? _missingColumnFrom(String? message) {
    if (message == null) return null;
    final match = RegExp(r"Could not find the '(\w+)' column").firstMatch(message);
    return match?.group(1);
  }

  String? _notNullColumnFrom(String? message) {
    if (message == null) return null;
    final match = RegExp(r'null value in column "(\w+)"').firstMatch(message);
    return match?.group(1);
  }

  Future<void> _writeRow(
    Future<void> Function(Map<String, dynamic>) op,
    Map<String, dynamic> data,
  ) async {
    var attempt = Map<String, dynamic>.from(data);
    String? lastFilledColumn;
    for (var i = 0; i < 10; i++) {
      try {
        await op(attempt);
        return;
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST204') {
          final column = _missingColumnFrom(e.message);
          if (column != null && attempt.containsKey(column)) {
            debugPrint('SettingsService: stripping unknown column "$column" from update (PGRST204)');
            attempt.remove(column);
            continue;
          }
        } else if (e.code == '23502') {
          final column = _notNullColumnFrom(e.message);
          if (column != null) {
            attempt[column] = '';
            lastFilledColumn = column;
            continue;
          }
        } else if (e.code == '22P02') {
          if (lastFilledColumn != null) {
            attempt[lastFilledColumn] = 0;
            continue;
          }
        }
        rethrow;
      }
    }
    throw Exception('تعذّر الحفظ بسبب اختلاف في مخطط قاعدة البيانات');
  }

  Future<void> _cacheSingleRow(String tableName, Map<String, dynamic>? row) async {
    if (row == null || row['id'] == null) return;
    await SyncService.instance.cacheRows(tableName, [row]);
  }

  String? _currentRole;

  Future<void> _loadUserRole() async {
    _currentRole = await getUserRole();
  }

  Future<void> _requireAdmin() async {
    if (_currentRole == null) {
      await _loadUserRole();
    }
    if (_currentRole != 'admin') {
      throw Exception('ليس لديك صلاحية للوصول إلى هذا القسم. يرجى الاتصال بالمسؤول.');
    }
  }

  Future<String?> getUserRole() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      final response = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return response?['role']?.toString();
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAppSettings() async {
    try {
      final response = await supabase
          .from('app_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      await _cacheSingleRow('app_settings', response);
      return response;
    } catch (e) {
      debugPrint('Error fetching app settings: $e');
      return null;
    }
  }

  Future<void> updateAppSettings(Map<String, dynamic> data) async {
    try {
      await _writeRow(
        (d) => supabase.from('app_settings').update(d).eq('id', 1),
        data,
      );
    } catch (e) {
      debugPrint('Error updating app settings: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getSystemSettings() async {
    try {
      final response = await supabase
          .from('system_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      await _cacheSingleRow('system_settings', response);
      return response;
    } catch (e) {
      debugPrint('Error fetching system settings: $e');
      return null;
    }
  }

  Future<void> updateSystemSettings(Map<String, dynamic> data) async {
    try {
      await _writeRow(
        (d) => supabase.from('system_settings').update(d).eq('id', 1),
        data,
      );
    } catch (e) {
      debugPrint('Error updating system settings: $e');
      rethrow;
    }
  }

  Future<String?> uploadCompanyLogo(String filePath) async {
    try {
      final fileName = 'company_logo_${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage.from('settings').upload(fileName, File(filePath));
      final url = supabase.storage.from('settings').getPublicUrl(fileName);
      await updateAppSettings({'company_logo_url': url});
      return url;
    } catch (e) {
      debugPrint('Error uploading company logo: $e');
      return null;
    }
  }

  Future<String?> uploadFleetDocImage(String filePath, {String? folder}) async {
    try {
      final fileName = 'fleet_doc_${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage.from('fleet_documents').upload(fileName, File(filePath));
      final url = supabase.storage.from('fleet_documents').getPublicUrl(fileName);
      return url;
    } catch (e) {
      debugPrint('Error uploading fleet doc image: $e');
      return null;
    }
  }

  Future<void> ensureUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final existing = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        await supabase.from('users').insert({
          'id': user.id,
          'email': user.email ?? '',
          'role': 'secretary',
        });
      }
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await supabase.from('users').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _requireAdmin();
      await supabase.from('users').update({'role': role}).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> calculateDriverSalary({
    required int driverId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final advances = await getAdvancesByDriver(driverId);
      double totalAdvances = 0.0;
      double totalSpent = 0.0;
      double totalReturned = 0.0;

      for (final advance in advances) {
        final dateOut = DateTime.tryParse(advance['date_out']?.toString() ?? '') ?? DateTime(2000);
        final dateReturn = advance['date_return'] != null ? DateTime.tryParse(advance['date_return'].toString()) : null;

        if (dateOut.isAfter(startDate.subtract(const Duration(days: 1))) && dateOut.isBefore(endDate.add(const Duration(days: 1)))) {
          totalAdvances += (advance['amount_given'] is Decimal ? (advance['amount_given'] as Decimal).toDouble() : (advance['amount_given'] as num?)?.toDouble()) ?? 0.0;
        }

        if (dateReturn != null && dateReturn.isAfter(startDate.subtract(const Duration(days: 1))) && dateReturn.isBefore(endDate.add(const Duration(days: 1)))) {
          totalSpent += (advance['amount_spent'] is Decimal ? (advance['amount_spent'] as Decimal).toDouble() : (advance['amount_spent'] as num?)?.toDouble()) ?? 0.0;
          totalReturned += (advance['amount_returned'] is Decimal ? (advance['amount_returned'] as Decimal).toDouble() : (advance['amount_returned'] as num?)?.toDouble()) ?? 0.0;
        }
      }

      final netSalary = totalAdvances - totalSpent + totalReturned;

      return {
        'driver_id': driverId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'total_advances': totalAdvances,
        'total_spent': totalSpent,
        'total_returned': totalReturned,
        'net_salary': netSalary,
      };
    } catch (e) {
      debugPrint('Error calculating driver salary: $e');
      return {'driver_id': driverId, 'net_salary': 0.0};
    }
  }

  Future<void> saveDriverSalary(Map<String, dynamic> salaryData) async {
    try {
      await _requireAdmin();
      await supabase.from('driver_salaries').insert(salaryData);
    } catch (e) {
      debugPrint('Error saving driver salary: $e');
      rethrow;
    }
  }

  Future<String?> uploadReceipt(String filePath) async {
    try {
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('receipts').upload(fileName, File(filePath));
      return supabase.storage.from('receipts').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      return null;
    }
  }

  Future<String?> uploadTripDocument(String filePath) async {
    try {
      final fileName = 'trip_doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('trip_documents').upload(fileName, File(filePath));
      return supabase.storage.from('trip_documents').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading trip document: $e');
      return null;
    }
  }

  Future<void> updateUserThemeMode(String userId, String themeMode) async {
    try {
      await supabase.from('user_preferences').upsert({
        'user_id': userId,
        'theme_mode': themeMode,
      });
    } catch (e) {
      debugPrint('Error updating user theme mode: $e');
    }
  }

  Future<Map<String, dynamic>> computeInvoiceTotals(double baseAmount, {String inputMode = 'HT'}) async {
    try {
      final base = Decimal.parse(baseAmount.toString());
      final settings = await getAppSettings();
      final isEnabled = settings?['is_enabled'] as bool? ?? false;
      final percentage = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;
      final tvaRate = Decimal.parse(percentage.toString());

      Decimal tva;
      Decimal total;

      if (isEnabled) {
        if (inputMode == 'HT') {
          final calc = CalculationEngine.calculate(amount: base, inputMode: 'HT', tvaRate: tvaRate);
          tva = calc.tvaAmount;
          total = calc.ttcAmount;
        } else {
          final calc = CalculationEngine.calculate(amount: base, inputMode: 'TTC', tvaRate: tvaRate);
          tva = calc.tvaAmount;
          total = calc.ttcAmount;
        }
      } else {
        tva = Decimal.zero;
        total = base;
      }

      return {
        'base': baseAmount,
        'tva': tva.toDouble(),
        'total': total.toDouble(),
      };
    } catch (e) {
      debugPrint('Error computing invoice totals: $e');
      return {'base': baseAmount, 'tva': 0.0, 'total': baseAmount};
    }
  }

  Future<Invoice> createInvoice({
    required int clientId,
    required Decimal amount,
    required String inputMode,
    String? bankAccountId,
    String? bankAccountType,
    String? bankInfoText,
    DateTime? issueDate,
    DateTime? dueDate,
  }) async {
    try {
      String? finalBankAccountId = bankAccountId;
      String? finalBankAccountType = bankAccountType;
      String? finalBankInfoText = bankInfoText;

      if (finalBankAccountId == null && finalBankAccountType == null) {
        final client = await supabase
            .from('clients')
            .select('default_bank_account_id, default_bank_account')
            .eq('id', clientId)
            .maybeSingle();
        final legacyDefaultId = client?['default_bank_account_id']?.toString();
        final newDefaultType = client?['default_bank_account']?.toString();
        if (newDefaultType == 'moroccan' || newDefaultType == 'european') {
          finalBankAccountType = newDefaultType;
        } else if (legacyDefaultId == 'moroccan' || legacyDefaultId == 'european') {
          finalBankAccountType = legacyDefaultId;
        }
        if (finalBankAccountType == null && legacyDefaultId != null) {
          finalBankAccountId = legacyDefaultId;
        }
      }

      if (finalBankAccountId == null && finalBankAccountType == null) {
        throw Exception('يرجى تحديد حساب بنكي للعميل أو اختيار حساب بنكي للفاتورة.');
      }

      String? currency;
      if (finalBankAccountId != null) {
        final bankResponse = await supabase.from('bank_accounts').select('currency').eq('id', finalBankAccountId).maybeSingle();
        currency = bankResponse?['currency']?.toString();
      }

      if (finalBankAccountType == null && currency != null) {
        finalBankAccountType = currency == 'EUR' ? 'european' : 'moroccan';
      }

      if (currency == null && finalBankAccountType != null) {
        currency = finalBankAccountType == 'european' ? 'EUR' : 'MAD';
      }

      if (finalBankAccountType != null && finalBankInfoText == null) {
        final sysSettings = await getSystemSettings();
        if (finalBankAccountType == 'moroccan') {
          finalBankInfoText = sysSettings?['bank_account_ma']?.toString();
        } else if (finalBankAccountType == 'european') {
          finalBankInfoText = sysSettings?['bank_account_eu']?.toString();
        }
      }

      final settings = await getAppSettings();
      final isEnabled = settings?['is_enabled'] as bool? ?? false;
      final percentage = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;

      final base = amount;
      final tvaRate = Decimal.parse(percentage.toString());

      Decimal htAmount;
      Decimal tvaAmount;
      Decimal ttcAmount;

      if (inputMode == 'HT') {
        htAmount = base;
        tvaAmount = isEnabled ? CalculationEngine.calculate(amount: base, inputMode: 'HT', tvaRate: tvaRate).tvaAmount : Decimal.zero;
        ttcAmount = isEnabled ? CalculationEngine.calculate(amount: base, inputMode: 'HT', tvaRate: tvaRate).ttcAmount : base;
      } else if (inputMode == 'TTC') {
        ttcAmount = base;
        htAmount = isEnabled ? CalculationEngine.calculate(amount: base, inputMode: 'TTC', tvaRate: tvaRate).htAmount : base;
        tvaAmount = isEnabled ? CalculationEngine.calculate(amount: base, inputMode: 'TTC', tvaRate: tvaRate).tvaAmount : Decimal.zero;
      } else {
        throw Exception('وضع الإدخال غير صالح. يجب أن يكون HT أو TTC.');
      }

      final now = DateTime.now();
      final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';

      final invoiceData = {
        'client_id': clientId,
        'invoice_number': invoiceNumber,
        'total_amount': ttcAmount.toDouble(),
        'paid_amount': 0.0,
        'status': 'unpaid',
        'issue_date': issueDate?.toIso8601String() ?? now.toIso8601String(),
        'due_date': dueDate?.toIso8601String() ?? now.add(const Duration(days: 30)).toIso8601String(),
        'bank_account_id': finalBankAccountId,
        'bank_account_type': finalBankAccountType,
        'bank_info_text': finalBankInfoText,
        'currency': currency ?? 'MAD',
        'input_mode': inputMode,
        'ht_amount': htAmount.toDouble(),
        'tva_rate': percentage,
        'tva_amount': tvaAmount.toDouble(),
        'ttc_amount': ttcAmount.toDouble(),
      };

      final response = await supabase
          .from('invoices')
          .insert(invoiceData)
          .select()
          .single();

      await _cacheSingleRow('invoices', response);
      return Invoice.fromMap(response);
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAdvancesByDriver(int driverId) async {
    try {
      final response = await supabase.from('advances').select().eq('driver_id', driverId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching advances by driver: $e');
      return [];
    }
  }
}


