import 'package:international_transport_app/models/client.dart';
import 'package:international_transport_app/services/cache_service.dart';
import 'package:international_transport_app/services/supabase_service.dart';

class CoreRepository {
  CoreRepository._();
  static CoreRepository? _instance;
  static CoreRepository get instance => _instance ??= CoreRepository._();

  final SupabaseService _supabaseService = SupabaseService();

  Future<List<Client>> getClients({bool activeOnly = false}) async {
    final cache = CacheService.instance;
    List<Client> clients = <Client>[];

    try {
      final cachedMaps = cache.getCachedClients();
      if (cachedMaps != null) {
        clients = cachedMaps.map((m) => Client.fromMap(m)).toList();
      }
    } catch (e) {
      clients = <Client>[];
    }

    try {
      final freshClients = await _supabaseService.getClients(activeOnly: activeOnly);
      if (freshClients.isNotEmpty) {
        await cache.cacheClients(freshClients.map((m) => m.toMap()).toList());
        return freshClients;
      }
    } catch (e) {
      if (clients.isNotEmpty) return clients;
      rethrow;
    }

    return clients;
  }

  Future<List<Map<String, dynamic>>> getTrucks() async {
    final cache = CacheService.instance;
    List<Map<String, dynamic>> trucks = <Map<String, dynamic>>[];

    try {
      final cached = cache.getCachedTrucks();
      if (cached != null) trucks = cached;
    } catch (e) {
      trucks = <Map<String, dynamic>>[];
    }

    try {
      final freshTrucks = await _supabaseService.getTrucks();
      if (freshTrucks.isNotEmpty) {
        await cache
            .cacheTrucks(freshTrucks.map((m) => Map<String, dynamic>.from(m)).toList());
        return freshTrucks;
      }
    } catch (e) {
      if (trucks.isNotEmpty) return trucks;
      rethrow;
    }

    return trucks;
  }

  Future<List<Map<String, dynamic>>> getDrivers() async {
    final cache = CacheService.instance;
    List<Map<String, dynamic>> drivers = <Map<String, dynamic>>[];

    try {
      final cached = cache.getCachedDrivers();
      if (cached != null) drivers = cached;
    } catch (e) {
      drivers = <Map<String, dynamic>>[];
    }

    try {
      final freshDrivers = await _supabaseService.getDrivers();
      if (freshDrivers.isNotEmpty) {
        await cache
            .cacheDrivers(freshDrivers.map((m) => Map<String, dynamic>.from(m)).toList());
        return freshDrivers;
      }
    } catch (e) {
      if (drivers.isNotEmpty) return drivers;
      rethrow;
    }

    return drivers;
  }

  Future<void> clearEntityCache(String entity) async {
    switch (entity) {
      case 'clients':
        await CacheService.instance.clearClientsCache();
        break;
      case 'trucks':
        await CacheService.instance.clearTrucksCache();
        break;
      case 'drivers':
        await CacheService.instance.clearDriversCache();
        break;
    }
  }
}
