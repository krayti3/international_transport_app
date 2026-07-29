import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class ReferenceService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

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
            debugPrint('ReferenceService: stripping unknown column "$column" from update (PGRST204)');
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

  // Countries CRUD
  Future<List<Map<String, dynamic>>> getCountries() async {
    try {
      final response = await supabase.from('countries').select().order('name', ascending: true);
      final countries = List<Map<String, dynamic>>.from(response);
      await _cacheRows('countries', countries);
      return countries;
    } catch (e) {
      debugPrint('Error fetching countries: $e');
      return [];
    }
  }

  Future<void> addCountry(Map<String, dynamic> data) async {
    try { await supabase.from('countries').insert(data); } catch (e) { debugPrint('Error adding country: $e'); rethrow; }
  }

  Future<void> updateCountry(int id, Map<String, dynamic> data) async {
    try { await _writeRow((d) => supabase.from('countries').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating country: $e'); rethrow; }
  }

  Future<void> deleteCountry(int id) async {
    try { await supabase.from('countries').delete().eq('id', id); } catch (e) { debugPrint('Error deleting country: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getCities() async {
    try {
      final response = await supabase.from('cities').select().order('name', ascending: true);
      final cities = List<Map<String, dynamic>>.from(response);
      await _cacheRows('cities', cities);
      return cities;
    } catch (e) {
      debugPrint('Error fetching cities: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCitiesByCountry(int countryId) async {
    try {
      final response = await supabase.from('cities').select().eq('country_id', countryId).order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching cities by country: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveCities() async {
    try {
      final response = await supabase.from('cities').select().eq('is_active', true).order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching active cities: $e');
      return [];
    }
  }

  Future<void> addCity(Map<String, dynamic> data) async {
    try { await supabase.from('cities').insert(data); } catch (e) { debugPrint('Error adding city: $e'); rethrow; }
  }

  Future<void> updateCity(int id, Map<String, dynamic> data) async {
    try { await _writeRow((d) => supabase.from('cities').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating city: $e'); rethrow; }
  }

  Future<void> deleteCity(int id) async {
    try { await supabase.from('cities').delete().eq('id', id); } catch (e) { debugPrint('Error deleting city: $e'); rethrow; }
  }

  Future<void> updateCityActiveStatus(int id, bool isActive) async {
    try { await supabase.from('cities').update({'is_active': isActive}).eq('id', id); } catch (e) { debugPrint('Error updating city active status: $e'); rethrow; }
  }

  // Currencies CRUD
  Future<List<Map<String, dynamic>>> getCurrencies() async {
    try {
      final response = await supabase.from('currencies').select().order('code', ascending: true);
      final currencies = List<Map<String, dynamic>>.from(response);
      await _cacheRows('currencies', currencies);
      return currencies;
    } catch (e) {
      debugPrint('Error fetching currencies: $e');
      return [];
    }
  }

  Future<void> addCurrency(Map<String, dynamic> data) async {
    try { await supabase.from('currencies').insert(data); } catch (e) { debugPrint('Error adding currency: $e'); rethrow; }
  }

  Future<void> updateCurrency(int id, Map<String, dynamic> data) async {
    try { await _writeRow((d) => supabase.from('currencies').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating currency: $e'); rethrow; }
  }

  Future<void> deleteCurrency(int id) async {
    try { await supabase.from('currencies').delete().eq('id', id); } catch (e) { debugPrint('Error deleting currency: $e'); rethrow; }
  }

  // Document Categories CRUD
  Future<List<Map<String, dynamic>>> getDocumentCategories() async {
    try {
      final response = await supabase.from('document_categories').select().order('name', ascending: true);
      final rows = List<Map<String, dynamic>>.from(response);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final row in rows) {
        final name = row['name']?.toString() ?? '';
        if (name.isEmpty || seen.contains(name)) continue;
        seen.add(name);
        deduped.add(row);
      }
      return deduped;
    } catch (e) {
      debugPrint('Error fetching document categories: $e');
      return [];
    }
  }

  Future<void> addDocumentCategory(Map<String, dynamic> data) async {
    try { await supabase.from('document_categories').insert(data); } catch (e) { debugPrint('Error adding document category: $e'); rethrow; }
  }

  Future<void> updateDocumentCategory(int id, Map<String, dynamic> data) async {
    try { await _writeRow((d) => supabase.from('document_categories').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating document category: $e'); rethrow; }
  }

  Future<void> deleteDocumentCategory(int id) async {
    try { await supabase.from('document_categories').delete().eq('id', id); } catch (e) { debugPrint('Error deleting document category: $e'); rethrow; }
  }

  // Exchange rates
  Future<Map<String, double>> getExchangeRates() async {
    try {
      final response = await supabase.from('exchange_rates').select().eq('is_active', true).order('from_currency');
      final rows = List<Map<String, dynamic>>.from(response);
      final rates = <String, double>{};
      for (final row in rows) {
        final from = row['from_currency']?.toString() ?? '';
        final to = row['to_currency']?.toString() ?? '';
        final rate = (row['rate'] as num?)?.toDouble() ?? 0.0;
        if (from.isNotEmpty && to.isNotEmpty) {
          rates['${from}_$to'] = rate;
        }
      }
      return rates;
    } catch (e) {
      debugPrint('Error fetching exchange rates: $e');
      return {};
    }
  }

  Future<void> updateExchangeRate(String fromCurrency, String toCurrency, double rate) async {
    try {
      await supabase.from('exchange_rates').upsert({
        'from_currency': fromCurrency,
        'to_currency': toCurrency,
        'rate': rate,
        'is_active': true,
      });
    } catch (e) {
      debugPrint('Error updating exchange rate: $e');
      rethrow;
    }
  }

  Future<bool> isDocumentCategoryInUse(int id) async {
    try {
      final response = await supabase.from('fleet_documents').select('id').eq('category_id', id).limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if document category is in use: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFleetDocuments() async {
    try {
      final response = await supabase.from('fleet_documents').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching fleet documents: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTruckDocuments() async {
    try {
      final response = await supabase.from('truck_documents').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching truck documents: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVehicleDocumentsByType(String entityType, {int? entityId}) async {
    try {
      var query = supabase.from('fleet_documents').select();
      if (entityType == 'truck') {
        query = supabase.from('truck_documents').select();
      }
      if (entityId != null) {
        query = query.eq('entity_id', entityId);
      }
      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching vehicle documents by type: $e');
      return [];
    }
  }

  Future<bool> hasTruckDocumentType(int truckId, String type) async {
    try {
      final response = await supabase.from('truck_documents').select('id').eq('truck_id', truckId).eq('type', type).limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking truck document type: $e');
      return false;
    }
  }

  Future<bool> hasFleetDocumentType(String entityType, int entityId, String categoryId) async {
    try {
      final response = await supabase.from('fleet_documents').select('id').eq('entity_type', entityType).eq('entity_id', entityId).eq('category_id', categoryId).limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking fleet document type: $e');
      return false;
    }
  }

  Future<void> addFleetDocument(Map<String, dynamic> data) async {
    try { await supabase.from('fleet_documents').insert(data); } catch (e) { debugPrint('Error adding fleet document: $e'); rethrow; }
  }

  Future<void> updateFleetDocument(int id, Map<String, dynamic> data) async {
    try { await supabase.from('fleet_documents').update(data).eq('id', id); } catch (e) { debugPrint('Error updating fleet document: $e'); rethrow; }
  }

  Future<void> deleteFleetDocument(int id) async {
    try { await supabase.from('fleet_documents').delete().eq('id', id); } catch (e) { debugPrint('Error deleting fleet document: $e'); rethrow; }
  }

  Future<void> addTruckDocument(Map<String, dynamic> data) async {
    try { await supabase.from('truck_documents').insert(data); } catch (e) { debugPrint('Error adding truck document: $e'); rethrow; }
  }

  Future<void> updateTruckDocument(int id, Map<String, dynamic> data) async {
    try { await supabase.from('truck_documents').update(data).eq('id', id); } catch (e) { debugPrint('Error updating truck document: $e'); rethrow; }
  }

  Future<void> deleteTruckDocument(int id) async {
    try { await supabase.from('truck_documents').delete().eq('id', id); } catch (e) { debugPrint('Error deleting truck document: $e'); rethrow; }
  }
}

