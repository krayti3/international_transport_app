import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/base_supabase_service.dart';

class FleetService extends BaseSupabaseService {

  // Trucks CRUD
  Future<List<Map<String, dynamic>>> getTrucks() async {
    try {
      final response = await supabase.from('trucks').select().order('id', ascending: true);
      final trucks = List<Map<String, dynamic>>.from(response);
      await cacheRows('trucks', trucks);
      return trucks;
    } catch (e) {
      debugPrint('Error fetching trucks: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrucksPage({int offset = 0, int limit = 20}) async {
    try {
      final response = await supabase.from('trucks').select().order('plate_number', ascending: true).range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching trucks page: $e');
      return [];
    }
  }

  Future<bool> checkTruckPlateUnique(String plate, {int? excludeId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('plate_number', plate);
      if (excludeId != null) query = query.neq('id', excludeId);
      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      debugPrint('Error checking truck plate uniqueness: $e');
      return true;
    }
  }

  Future<bool> checkTrailerPlateUnique(String plate, {int? excludeId}) async {
    try {
      var query = supabase.from('trailers').select('id').eq('plate_number', plate);
      if (excludeId != null) query = query.neq('id', excludeId);
      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      debugPrint('Error checking trailer plate uniqueness: $e');
      return true;
    }
  }

  Future<bool> checkDefaultTrailerAvailable(int trailerId, {int? excludeTruckId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('default_trailer_id', trailerId);
      if (excludeTruckId != null) query = query.neq('id', excludeTruckId);
      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      debugPrint('Error checking default trailer availability: $e');
      return true;
    }
  }

  Future<int?> reassignDefaultTrailer(int trailerId, {int? excludeTruckId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('default_trailer_id', trailerId);
      if (excludeTruckId != null) query = query.neq('id', excludeTruckId);
      final otherTruck = await query.maybeSingle();
      if (otherTruck == null) return null;
      final otherTruckId = otherTruck['id'] as int;
      await supabase.from('trucks').update({'default_trailer_id': null}).eq('id', otherTruckId);
      return otherTruckId;
    } on PostgrestException catch (e) {
      debugPrint('Error reassigning default trailer: $e');
      return null;
    } catch (e) {
      debugPrint('Error reassigning default trailer: $e');
      return null;
    }
  }

  Future<bool> checkDefaultDriverAvailable(int driverId, {int? excludeTruckId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('default_driver_id', driverId);
      if (excludeTruckId != null) query = query.neq('id', excludeTruckId);
      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      debugPrint('Error checking default driver availability: $e');
      return true;
    }
  }

  Future<int?> reassignDefaultDriver(int driverId, {int? excludeTruckId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('default_driver_id', driverId);
      if (excludeTruckId != null) query = query.neq('id', excludeTruckId);
      final otherTruck = await query.maybeSingle();
      if (otherTruck == null) return null;
      final otherTruckId = otherTruck['id'] as int;
      await supabase.from('trucks').update({'default_driver_id': null}).eq('id', otherTruckId);
      return otherTruckId;
    } on PostgrestException catch (e) {
      debugPrint('Error reassigning default driver: $e');
      return null;
    } catch (e) {
      debugPrint('Error reassigning default driver: $e');
      return null;
    }
  }

  Future<void> addTruck(Map<String, dynamic> data) async {
    await writeRow((d) => supabase.from('trucks').insert(d), data);
  }

  Future<void> updateTruck(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await writeRow((d) => supabase.from('trucks').update(d).eq('id', id), data);
      return;
    }
    await updateWithLww(() => writeRow((d) => supabase.from('trucks').update(d).eq('id', id), data), 'trucks', localRow);
  }

  Future<void> deleteTruck(int id) async {
    try { await supabase.from('trucks').delete().eq('id', id); } catch (e) { debugPrint('Error deleting truck: $e'); rethrow; }
  }

  Future<void> updateTruckLocation(int id, double latitude, double longitude) async {
    try { await supabase.from('trucks').update({'current_latitude': latitude, 'current_longitude': longitude, 'last_updated': DateTime.now().toIso8601String()}).eq('id', id); } catch (e) { debugPrint('Error updating truck location: $e'); rethrow; }
  }

  Future<void> recordTruckLocation(int truckId, double latitude, double longitude) async {
    try { await supabase.from('truck_locations').insert({'truck_id': truckId, 'latitude': latitude, 'longitude': longitude, 'recorded_at': DateTime.now().toIso8601String()}); } catch (e) { debugPrint('Error recording truck location: $e'); }
  }

  Future<List<Map<String, dynamic>>> getTruckLocationHistory(int truckId, {int hours = 24}) async {
    try { final since = DateTime.now().subtract(Duration(hours: hours)).toIso8601String(); final response = await supabase.from('truck_locations').select().eq('truck_id', truckId).gte('recorded_at', since).order('recorded_at', ascending: true); return List<Map<String, dynamic>>.from(response); } catch (e) { debugPrint('Error fetching truck location history: $e'); return []; }
  }

  // Truck Maintenance
  Future<List<Map<String, dynamic>>> getTruckMaintenances() async {
    try { final response = await supabase.from('truck_maintenance').select().order('created_at', ascending: false); final maintenances = List<Map<String, dynamic>>.from(response); await cacheRows('truck_maintenance', maintenances); return maintenances; } catch (e) { debugPrint('Error fetching truck maintenances: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getTruckMaintenancesByTruck(int truckId) async {
    try { final response = await supabase.from('truck_maintenance').select().eq('truck_id', truckId).order('created_at', ascending: false); final maintenances = List<Map<String, dynamic>>.from(response); await cacheRows('truck_maintenance', maintenances); return maintenances; } catch (e) { debugPrint('Error fetching truck maintenances by truck: $e'); return []; }
  }

  Future<void> addTruckMaintenance(Map<String, dynamic> data) async {
    await writeRow((d) => supabase.from('truck_maintenance').insert(d), data);
  }

  Future<void> updateTruckMaintenance(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await writeRow((d) => supabase.from('truck_maintenance').update(d).eq('id', id), data);
      return;
    }
    await updateWithLww(() => writeRow((d) => supabase.from('truck_maintenance').update(d).eq('id', id), data), 'truck_maintenance', localRow);
  }

  Future<void> deleteTruckMaintenance(int id) async {
    try { await supabase.from('truck_maintenance').delete().eq('id', id); } catch (e) { debugPrint('Error deleting truck maintenance: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getTruckMaintenancesFiltered({int? truckId, String? paymentStatus, DateTime? fromDate, DateTime? toDate}) async {
    try { var query = supabase.from('truck_maintenance').select(); if (truckId != null) query = query.eq('truck_id', truckId); if (paymentStatus != null) query = query.eq('payment_status', paymentStatus); if (fromDate != null) query = query.gte('maintenance_date', fromDate.toIso8601String()); if (toDate != null) query = query.lt('maintenance_date', toDate.toIso8601String()); final response = await query.order('maintenance_date', ascending: false); final maintenances = List<Map<String, dynamic>>.from(response); await cacheRows('truck_maintenance', maintenances); return maintenances; } catch (e) { debugPrint('Error fetching filtered truck maintenances: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getMaintenancesByExpenseType(String expenseType) async {
    try { final combined = <Map<String, dynamic>>[]; final truckResponse = await supabase.from('truck_maintenance').select().eq('expense_type', expenseType).order('maintenance_date', ascending: false); for (final row in truckResponse) { final doc = Map<String, dynamic>.from(row); doc['vehicle_type'] = 'truck'; doc['vehicle_id'] = doc['truck_id']; combined.add(doc); } final trailerResponse = await supabase.from('trailer_maintenance').select().eq('expense_type', expenseType).order('maintenance_date', ascending: false); for (final row in trailerResponse) { final doc = Map<String, dynamic>.from(row); doc['vehicle_type'] = 'trailer'; doc['vehicle_id'] = doc['trailer_id']; combined.add(doc); } combined.sort((a, b) { final aDate = a['maintenance_date']?.toString() ?? ''; final bDate = b['maintenance_date']?.toString() ?? ''; return bDate.compareTo(aDate); }); return combined; } catch (e) { debugPrint('Error fetching maintenances by expense type: $e'); return []; }
  }

  // Trailer Maintenance
  Future<List<Map<String, dynamic>>> getTrailerMaintenances() async {
    try { final response = await supabase.from('trailer_maintenance').select().order('created_at', ascending: false); final maintenances = List<Map<String, dynamic>>.from(response); await cacheRows('trailer_maintenance', maintenances); return maintenances; } catch (e) { debugPrint('Error fetching trailer maintenances: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getTrailerMaintenancesByTrailer(int trailerId) async {
    try { final response = await supabase.from('trailer_maintenance').select().eq('trailer_id', trailerId).order('created_at', ascending: false); final maintenances = List<Map<String, dynamic>>.from(response); await cacheRows('trailer_maintenance', maintenances); return maintenances; } catch (e) { debugPrint('Error fetching trailer maintenances by trailer: $e'); return []; }
  }

  Future<void> addTrailerMaintenance(Map<String, dynamic> data) async {
    await writeRow((d) => supabase.from('trailer_maintenance').insert(d), data);
  }

  Future<void> updateTrailerMaintenance(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await writeRow((d) => supabase.from('trailer_maintenance').update(d).eq('id', id), data);
      return;
    }
    await updateWithLww(() => writeRow((d) => supabase.from('trailer_maintenance').update(d).eq('id', id), data), 'trailer_maintenance', localRow);
  }

  Future<void> deleteTrailerMaintenance(int id) async {
    try { await supabase.from('trailer_maintenance').delete().eq('id', id); } catch (e) { debugPrint('Error deleting trailer maintenance: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getTrailerMaintenancesFiltered({int? trailerId, String? paymentStatus, DateTime? fromDate, DateTime? toDate}) async {
    try { var query = supabase.from('trailer_maintenance').select(); if (trailerId != null) query = query.eq('trailer_id', trailerId); if (paymentStatus != null) query = query.eq('payment_status', paymentStatus); if (fromDate != null) query = query.gte('maintenance_date', fromDate.toIso8601String()); if (toDate != null) query = query.lt('maintenance_date', toDate.toIso8601String()); final response = await query.order('maintenance_date', ascending: false); final maintenances = List<Map<String, dynamic>>.from(response); await cacheRows('trailer_maintenance', maintenances); return maintenances; } catch (e) { debugPrint('Error fetching filtered trailer maintenances: $e'); return []; }
  }

  Future<List<String>> getExpenseTypes() async {
    try { final response = await supabase.from('truck_maintenance').select('expense_type').order('expense_type'); final raw = List<Map<String, dynamic>>.from(response); final types = <String>{}; for (final row in raw) { final value = row['expense_type']?.toString(); if (value != null && value.isNotEmpty) types.add(value); } return types.toList()..sort(); } catch (e) { debugPrint('Error fetching expense types: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getOilChangeAlerts() async {
    try { final response = await supabase.from('trucks').select().gt('oil_change_km', 0).order('current_km', ascending: true); final trucks = List<Map<String, dynamic>>.from(response); final alerts = <Map<String, dynamic>>[]; for (final truck in trucks) { final currentKm = (truck['current_km'] as num?)?.toDouble() ?? 0; final oilChangeKm = (truck['oil_change_km'] as num?)?.toDouble() ?? 0; if (oilChangeKm > 0 && currentKm >= oilChangeKm * 0.9) { alerts.add({...truck, 'km_remaining': oilChangeKm - currentKm, 'percentage': (currentKm / oilChangeKm * 100).toInt()}); } } return alerts; } catch (e) { debugPrint('Error fetching oil change alerts: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getOilChangeRecords() async {
    try { final response = await supabase.from('truck_maintenance').select().eq('expense_type', 'oil_change').order('created_at', ascending: false); final records = List<Map<String, dynamic>>.from(response); await cacheRows('truck_maintenance_oil', records); return records; } catch (e) { debugPrint('Error fetching oil change records: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getOilChangeRecordsByTruck(int truckId) async {
    try { final response = await supabase.from('truck_maintenance').select().eq('truck_id', truckId).eq('expense_type', 'oil_change').order('created_at', ascending: false); final records = List<Map<String, dynamic>>.from(response); await cacheRows('truck_maintenance_oil', records); return records; } catch (e) { debugPrint('Error fetching oil change records by truck: $e'); return []; }
  }

  Future<Map<String, double>> getTruckMaintenanceTotals() async {
    try { final response = await supabase.from('truck_maintenance').select('amount'); final rows = List<Map<String, dynamic>>.from(response); double total = 0.0; for (final row in rows) { total += (row['amount'] as num?)?.toDouble() ?? 0.0; } return {'total': total}; } catch (e) { debugPrint('Error calculating truck maintenance totals: $e'); return {'total': 0.0}; }
  }

  // Trailers CRUD
  Future<List<Map<String, dynamic>>> getTrailers() async {
    try { final response = await supabase.from('trailers').select().order('id', ascending: true); final trailers = List<Map<String, dynamic>>.from(response); await cacheRows('trailers', trailers); return trailers; } catch (e) { debugPrint('Error fetching trailers: $e'); return []; }
  }

  Future<int?> addTrailer(Map<String, dynamic> data) async {
    try { final response = await supabase.from('trailers').insert(data).select('id').single(); return response['id'] as int?; } catch (e) { debugPrint('Error adding trailer: $e'); rethrow; }
  }

  Future<void> updateTrailer(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await writeRow((d) => supabase.from('trailers').update(d).eq('id', id), data);
      return;
    }
    await updateWithLww(() => writeRow((d) => supabase.from('trailers').update(d).eq('id', id), data), 'trailers', localRow);
  }

  Future<void> deleteTrailer(int id) async {
    try { await supabase.from('trailers').delete().eq('id', id); } catch (e) { debugPrint('Error deleting trailer: $e'); rethrow; }
  }

  // Fleet Documents CRUD
  Future<List<Map<String, dynamic>>> getDocuments() async {
    try { final response = await supabase.from('documents').select().order('expiry_date', ascending: true); final documents = List<Map<String, dynamic>>.from(response); await cacheRows('documents', documents); return documents; } catch (e) { debugPrint('Error fetching documents: $e'); return []; }
  }

  Future<void> addDocument(Map<String, dynamic> data) async {
    await writeRow((d) => supabase.from('documents').insert(d), data);
  }

  Future<void> deleteDocument(int id) async {
    try { await supabase.from('documents').delete().eq('id', id); } catch (e) { debugPrint('Error deleting document: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getDocumentCategories() async {
    try { final response = await supabase.from('document_categories').select().order('name', ascending: true); final rows = List<Map<String, dynamic>>.from(response); final seen = <String>{}; final deduped = <Map<String, dynamic>>[]; for (final row in rows) { final name = row['name']?.toString() ?? ''; if (name.isEmpty || seen.contains(name)) continue; seen.add(name); deduped.add(row); } return deduped; } catch (e) { debugPrint('Error fetching document categories: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getFleetDocumentsByDocType(String docType) async {
    try { final response = await supabase.from('fleet_documents').select().eq('doc_type', docType).order('expiry_date', ascending: true); return List<Map<String, dynamic>>.from(response); } catch (e) { debugPrint('Error fetching fleet documents by doc type: $e'); return []; }
  }

  Future<Map<String, dynamic>?> getVehicleInfo(String entityType, int entityId) async {
    try { if (entityType == 'truck') { final response = await supabase.from('trucks').select().eq('id', entityId).maybeSingle(); return response != null ? Map<String, dynamic>.from(response) : null; } else if (entityType == 'trailer') { final response = await supabase.from('trailers').select().eq('id', entityId).maybeSingle(); return response != null ? Map<String, dynamic>.from(response) : null; } return null; } catch (e) { debugPrint('Error fetching vehicle info: $e'); return null; }
  }

  Future<List<Map<String, dynamic>>> getVehicleDocumentsByType({required String entityType, required int entityId, required String docType}) async {
    try { final List<Map<String, dynamic>> combined = []; final fleetResponse = await supabase.from('fleet_documents').select().eq('entity_type', entityType).eq('entity_id', entityId).eq('doc_type', docType).order('expiry_date', ascending: true); for (final row in fleetResponse) { combined.add(Map<String, dynamic>.from(row)); combined.last['_source'] = 'fleet'; } if (entityType == 'truck') { final truckResponse = await supabase.from('truck_documents').select().eq('truck_id', entityId).eq('type', docType).order('expiry_date', ascending: true); for (final row in truckResponse) { final doc = Map<String, dynamic>.from(row); doc['entity_type'] = 'truck'; doc['entity_id'] = doc['truck_id']; doc['doc_type'] = doc['type']; doc['_source'] = 'truck_legacy'; combined.add(doc); } } combined.sort((a, b) { final aDate = a['expiry_date']?.toString() ?? ''; final bDate = b['expiry_date']?.toString() ?? ''; return aDate.compareTo(bDate); }); return combined; } catch (e) { debugPrint('Error fetching vehicle documents by type: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getDocumentsByDocType(String docType) async {
    try { final fleetResponse = await supabase.from('fleet_documents').select().eq('doc_type', docType).order('expiry_date', ascending: true); final truckResponse = await supabase.from('truck_documents').select().eq('type', docType).order('expiry_date', ascending: true); final combined = <Map<String, dynamic>>[]; for (final row in fleetResponse) { combined.add(Map<String, dynamic>.from(row)); } for (final row in truckResponse) { final doc = Map<String, dynamic>.from(row); doc['entity_type'] = 'truck'; doc['entity_id'] = doc['truck_id']; doc['doc_type'] = doc['type']; combined.add(doc); } combined.sort((a, b) { final aDate = a['expiry_date']?.toString() ?? ''; final bDate = b['expiry_date']?.toString() ?? ''; return aDate.compareTo(bDate); }); return combined; } catch (e) { debugPrint('Error fetching documents by doc type: $e'); return []; }
  }

  Future<void> addDocumentCategory(Map<String, dynamic> data) async {
    try { await supabase.from('document_categories').insert(data); } catch (e) { debugPrint('Error adding document category: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getFleetDocuments({String? entityType, int? entityId}) async {
    try { var query = supabase.from('fleet_documents').select(); if (entityType != null) query = query.eq('entity_type', entityType); if (entityId != null) query = query.eq('entity_id', entityId); final response = await query.order('expiry_date', ascending: true); return List<Map<String, dynamic>>.from(response); } catch (e) { debugPrint('Error fetching fleet documents: $e'); return []; }
  }

  Future<void> addFleetDocument(Map<String, dynamic> data) async {
    try { await writeRow((d) => supabase.from('fleet_documents').insert(d), data); } catch (e) { debugPrint('Error adding fleet document: $e'); rethrow; }
  }

  Future<bool> hasFleetDocumentType(String entityType, int entityId, String docType) async {
    try { final result = await supabase.from('fleet_documents').select('id').eq('entity_type', entityType).eq('entity_id', entityId).eq('doc_type', docType).maybeSingle(); return result != null; } catch (e) { debugPrint('Error checking fleet document type: $e'); return false; }
  }

  Future<void> updateFleetDocument(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try { Future<void> updateOp() => supabase.from('fleet_documents').update(data).eq('id', id); if (localRow == null) { await updateOp(); } else { await updateWithLww(updateOp, 'fleet_documents', localRow); } } catch (e) { debugPrint('Error updating fleet document: $e'); rethrow; }
  }

  Future<void> deleteFleetDocument(int id) async {
    try { await supabase.from('fleet_documents').delete().eq('id', id); } catch (e) { debugPrint('Error deleting fleet document: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getExpiringFleetDocs({int daysThreshold = 30}) async {
    try { final now = DateTime.now(); final threshold = now.add(Duration(days: daysThreshold)); final thresholdStr = threshold.toIso8601String().split('T').first; final response = await supabase.from('fleet_documents').select('*').lte('expiry_date', thresholdStr).order('expiry_date', ascending: true); final docs = List<Map<String, dynamic>>.from(response); return docs.where((doc) => doc['expiry_date'] != null).toList(); } catch (e) { debugPrint('Error fetching expiring fleet documents: $e'); return []; }
  }

  // Truck Documents CRUD
  Future<List<Map<String, dynamic>>> getTruckDocuments() async {
    try { final response = await supabase.from('truck_documents').select().order('expiry_date', ascending: true); return List<Map<String, dynamic>>.from(response); } catch (e) { debugPrint('Error fetching truck documents: $e'); return []; }
  }

  Future<int> addTruckDocument(Map<String, dynamic> data) async {
    try { final response = await supabase.from('truck_documents').insert(data).select('id').single(); return response['id'] as int; } catch (e) { debugPrint('Error adding truck document: $e'); rethrow; }
  }

  Future<bool> hasTruckDocumentType(int truckId, String type) async {
    try { final result = await supabase.from('truck_documents').select('id').eq('truck_id', truckId).eq('type', type).maybeSingle(); return result != null; } catch (e) { debugPrint('Error checking truck document type: $e'); return false; }
  }

  Future<void> updateTruckDocument(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try { Future<void> updateOp() => supabase.from('truck_documents').update(data).eq('id', id); if (localRow == null) { await updateOp(); } else { await updateWithLww(updateOp, 'truck_documents', localRow); } } catch (e) { debugPrint('Error updating truck document: $e'); rethrow; }
  }

  Future<void> deleteTruckDocument(int id) async {
    try { await supabase.from('truck_documents').delete().eq('id', id); } catch (e) { debugPrint('Error deleting truck document: $e'); rethrow; }
  }

  // Drivers CRUD
  Future<int?> addDriver(Map<String, dynamic> data) async {
    try { final response = await supabase.from('drivers').insert(data).select('id').single(); return response['id'] as int?; } catch (e) { debugPrint('Error adding driver: $e'); rethrow; }
  }

  Future<void> updateDriver(int id, Map<String, dynamic> data) async {
    await writeRow((d) => supabase.from('drivers').update(d).eq('id', id), data);
  }

  Future<void> deleteDriver(int id) async {
    try { await supabase.from('drivers').delete().eq('id', id); } catch (e) { debugPrint('Error deleting driver: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getDrivers() async {
    try { final response = await supabase.from('drivers').select(); final drivers = List<Map<String, dynamic>>.from(response); await cacheRows('drivers', drivers); return drivers; } catch (e) { debugPrint('Error fetching drivers: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getDriversPage({int offset = 0, int limit = 20}) async {
    try { final response = await supabase.from('drivers').select().order('name', ascending: true).range(offset, offset + limit - 1); return List<Map<String, dynamic>>.from(response); } catch (e) { debugPrint('Error fetching drivers page: $e'); return []; }
  }

  Future<void> updateDriverVisa(String driverId, String visaNumber, DateTime expiryDate) async {
    try { await writeRow((d) => supabase.from('drivers').update({'visa_number': visaNumber, 'visa_expiry_date': expiryDate.toIso8601String().split('T').first, 'has_valid_visa': true}).eq('id', int.parse(driverId)), {'visa_number': visaNumber, 'visa_expiry_date': expiryDate.toIso8601String().split('T').first, 'has_valid_visa': true}); } catch (e) { debugPrint('Error updating driver visa: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getExpiringVisas({int daysThreshold = 30}) async {
    try { final allDrivers = await getDrivers(); final now = DateTime.now(); final threshold = now.add(Duration(days: daysThreshold)); return allDrivers.where((driver) { final expiryStr = driver['visa_expiry_date']?.toString(); if (expiryStr == null || expiryStr.isEmpty) return false; final expiryDate = DateTime.tryParse(expiryStr); if (expiryDate == null) return false; return expiryDate.isBefore(threshold) || expiryDate.isAtSameMomentAs(now); }).toList(); } catch (e) { debugPrint('Error fetching expiring visas: $e'); return []; }
  }

  // Maintenance Schedule CRUD
  Future<List<Map<String, dynamic>>> getMaintenanceSchedules({String? vehicleType, int? vehicleId, String? status}) async {
    try { var query = supabase.from('maintenance_schedule').select(); if (vehicleType != null) query = query.eq('vehicle_type', vehicleType); if (vehicleId != null) query = query.eq('vehicle_id', vehicleId); if (status != null) query = query.eq('status', status); final response = await query.eq('is_deleted', false).order('scheduled_date', ascending: true); return List<Map<String, dynamic>>.from(response); } catch (e) { debugPrint('Error fetching maintenance schedules: $e'); return []; }
  }

  Future<List<Map<String, dynamic>>> getUpcomingMaintenances({int? daysAhead}) async {
    try { final now = DateTime.now(); final until = daysAhead != null ? now.add(Duration(days: daysAhead)) : null; var query = supabase.from('maintenance_schedule').select().eq('is_deleted', false).neq('status', 'completed').gte('scheduled_date', now.toIso8601String().split('T').first); if (until != null) query = query.lte('scheduled_date', until.toIso8601String().split('T').first); final response = await query.order('scheduled_date', ascending: true); return List<Map<String, dynamic>>.from(response); } catch (e) { debugPrint('Error fetching upcoming maintenances: $e'); return []; }
  }

  Future<Map<String, dynamic>?> getMaintenanceSchedule(int id) async {
    try { final response = await supabase.from('maintenance_schedule').select().eq('id', id).eq('is_deleted', false).maybeSingle(); return response; } catch (e) { debugPrint('Error fetching maintenance schedule: $e'); return null; }
  }

  Future<int?> insertMaintenanceSchedule(Map<String, dynamic> data) async {
    try { final payload = Map<String, dynamic>.from(data); payload.remove('id'); payload.remove('created_at'); payload.remove('updated_at'); payload['notification_sent'] = false; final response = await supabase.from('maintenance_schedule').insert(payload).select().single(); return response['id'] as int?; } catch (e) { debugPrint('Error inserting maintenance schedule: $e'); rethrow; }
  }

  Future<void> updateMaintenanceSchedule(int id, Map<String, dynamic> data) async {
    try { final payload = Map<String, dynamic>.from(data); payload.remove('created_at'); await supabase.from('maintenance_schedule').update(payload).eq('id', id); } catch (e) { debugPrint('Error updating maintenance schedule: $e'); rethrow; }
  }

  Future<void> deleteMaintenanceSchedule(int id) async {
    try { await supabase.from('maintenance_schedule').update({'is_deleted': true}).eq('id', id); } catch (e) { debugPrint('Error deleting maintenance schedule: $e'); rethrow; }
  }

  Future<void> completeMaintenanceSchedule(int id, {double? completedKm, double? actualCost, String? notes}) async {
    try { final updates = <String, dynamic>{'status': 'completed', 'completed_at': DateTime.now().toIso8601String()}; if (completedKm != null) updates['completed_km'] = completedKm; if (actualCost != null) updates['actual_cost'] = actualCost; if (notes != null && notes.isNotEmpty) updates['notes'] = notes; await supabase.from('maintenance_schedule').update(updates).eq('id', id); } catch (e) { debugPrint('Error completing maintenance schedule: $e'); rethrow; }
  }

  Future<void> markOverdueMaintenances() async {
    try { final today = DateTime.now().toIso8601String().split('T').first; await supabase.from('maintenance_schedule').update({'status': 'overdue'}).eq('is_deleted', false).neq('status', 'completed').neq('status', 'skipped').lt('scheduled_date', today); } catch (e) { debugPrint('Error marking overdue maintenances: $e'); }
  }

  Future<Map<String, dynamic>> calculateDriverSalary({
    required String driverId,
    required int month,
    required int year,
  }) async {
    try {
      final driverResponse = await supabase
          .from('drivers')
          .select('base_salary, bonus_percentage')
          .eq('id', driverId)
          .maybeSingle();

      final baseSalary = (driverResponse?['base_salary'] as num?)?.toDouble() ?? 0.0;
      final bonusPercentage = (driverResponse?['bonus_percentage'] as num?)?.toDouble() ?? 0.0;

      final startDate = DateTime(year, month, 1);
      final endDate = month == 12
          ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      final tripsResponse = await supabase
          .from('trip_orders')
          .select('id, price, status, departure_date')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .gte('departure_date', startDate.toIso8601String().split('T').first)
          .lte('departure_date', endDate.toIso8601String().split('T').first);
      final trips = List<Map<String, dynamic>>.from(tripsResponse);

      int completedTrips = trips.length;
      double totalTripValue = 0.0;
      for (final trip in trips) {
        totalTripValue += (trip['price'] as num?)?.toDouble() ?? 0.0;
      }

      final bonusAmount = totalTripValue * (bonusPercentage / 100);
      final totalSalary = baseSalary + bonusAmount;

      return {
        'driver_id': driverId,
        'base_salary': baseSalary,
        'bonus_percentage': bonusPercentage,
        'completed_trips_count': completedTrips,
        'total_trip_value': totalTripValue,
        'bonus_amount': bonusAmount,
        'total_salary': totalSalary,
      };
    } catch (e) {
      debugPrint('Error calculating driver salary: $e');
      return {'driver_id': driverId, 'total_salary': 0.0};
    }
  }

  Future<bool> isDriverInUse(int driverId) async {
    try {
      final advances = await supabase.from('advances').select('id').eq('driver_id', driverId).limit(1);
      if ((advances as List).isNotEmpty) return true;
      final trips = await supabase.from('trip_orders').select('id').eq('driver_id', driverId).limit(1);
      if ((trips as List).isNotEmpty) return true;
      return false;
    } catch (e) {
      debugPrint('Error checking if driver is in use: $e');
      return false;
    }
  }

  Future<bool> isTrailerInUse(int trailerId) async {
    try {
      final trucks = await supabase.from('trucks').select('id').eq('default_trailer_id', trailerId).limit(1);
      if ((trucks as List).isNotEmpty) return true;
      final maintenances = await supabase.from('trailer_maintenances').select('id').eq('trailer_id', trailerId).limit(1);
      if ((maintenances as List).isNotEmpty) return true;
      final docs = await supabase.from('fleet_documents').select('id').eq('entity_type', 'trailer').eq('entity_id', trailerId).limit(1);
      if ((docs as List).isNotEmpty) return true;
      return false;
    } catch (e) {
      debugPrint('Error checking if trailer is in use: $e');
      return false;
    }
  }

  Future<bool> isTruckInUse(int truckId) async {
    try {
      final maintenances = await supabase.from('truck_maintenances').select('id').eq('truck_id', truckId).limit(1);
      if ((maintenances as List).isNotEmpty) return true;
      final docs = await supabase.from('truck_documents').select('id').eq('truck_id', truckId).limit(1);
      if ((docs as List).isNotEmpty) return true;
      final trips = await supabase.from('trip_orders').select('id').eq('truck_id', truckId).limit(1);
      if ((trips as List).isNotEmpty) return true;
      return false;
    } catch (e) {
      debugPrint('Error checking if truck is in use: $e');
      return false;
    }
  }

  Future<String> uploadFleetDocImage({
    required String entityType,
    required int entityId,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'fleet_docs/$entityType/$entityId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await supabase.storage.from('fleet_docs').uploadBinary(path, Uint8List.fromList(bytes));
      return supabase.storage.from('fleet_docs').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading fleet doc image: $e');
      rethrow;
    }
  }
}


