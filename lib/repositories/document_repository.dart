import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class DocumentRepository {
  final SupabaseClient supabase;

  DocumentRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final response = await supabase.from('documents').select();
      final docs = List<Map<String, dynamic>>.from(response);
      await _cacheRows('documents', response);
      return docs;
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      return [];
    }
  }

  Future<void> addDocument(Map<String, dynamic> data) async {
    try {
      await supabase.from('documents').insert(data);
    } catch (e) {
      debugPrint('Error adding document: $e');
      rethrow;
    }
  }

  Future<void> updateDocument(int id, Map<String, dynamic> data) async {
    try {
      await supabase.from('documents').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating document: $e');
      rethrow;
    }
  }

  Future<void> deleteDocument(int id) async {
    try {
      await supabase.from('documents').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }
}
