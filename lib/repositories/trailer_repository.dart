import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/trailer.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/fleet_service.dart';

class TrailerRepository {
  final SupabaseClient supabase;
  final FleetService _fleetService = FleetService();

  TrailerRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Trailer>> getCachedTrailers() async {
    final rows = await SyncService.instance.getAllCachedRows('trailers');
    if (rows == null) return const [];
    return rows.map((e) => Trailer.fromMap(e)).toList();
  }

  Future<List<Trailer>> getTrailers() async {
    try {
      final trailers = await _fleetService.getTrailers();
      await _cacheRows('trailers', trailers);
      return trailers.map((e) => Trailer.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching trailers: $e');
      return [];
    }
  }

  Future<void> addTrailer(Map<String, dynamic> data) async {
    try {
      await _fleetService.addTrailer(data);
    } catch (e) {
      debugPrint('Error adding trailer: $e');
      rethrow;
    }
  }

  Future<void> updateTrailer(int id, Map<String, dynamic> data) async {
    try {
      await _fleetService.updateTrailer(id, data);
    } catch (e) {
      debugPrint('Error updating trailer: $e');
      rethrow;
    }
  }

  Future<void> deleteTrailer(int id) async {
    try {
      await _fleetService.deleteTrailer(id);
    } catch (e) {
      debugPrint('Error deleting trailer: $e');
      rethrow;
    }
  }
}
