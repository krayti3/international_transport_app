import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/fleet_service.dart';

class DocumentRepository {
  final SupabaseClient supabase;
  final FleetService _fleetService = FleetService();

  DocumentRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final docs = await _fleetService.getDocuments();
      await _cacheRows('documents', docs);
      return docs;
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      return [];
    }
  }

  Future<void> addDocument(Map<String, dynamic> data) async {
    try {
      await _fleetService.addDocument(data);
    } catch (e) {
      debugPrint('Error adding document: $e');
      rethrow;
    }
  }

  Future<void> updateDocument(int id, Map<String, dynamic> data) async {
    try {
      await _fleetService.updateFleetDocument(id, data);
    } catch (e) {
      debugPrint('Error updating document: $e');
      rethrow;
    }
  }

  Future<void> deleteDocument(int id) async {
    try {
      await _fleetService.deleteDocument(id);
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }
}
