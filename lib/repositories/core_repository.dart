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

    Future.microtask(() async {
      try {
        final fresh = await _supabaseService.getClients(activeOnly: activeOnly);
        if (fresh.isNotEmpty) {
          await cache.cacheClients(fresh.map((m) => m.toMap()).toList());
        }
      } catch (e) {
        // silent
      }
    });

    if (clients.isNotEmpty) return clients;
    final fresh = await _supabaseService.getClients(activeOnly: activeOnly);
    if (fresh.isNotEmpty) {
      await cache.cacheClients(fresh.map((m) => m.toMap()).toList());
    }
    return fresh;
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

    Future.microtask(() async {
      try {
        final fresh = await _supabaseService.getTrucks();
        if (fresh.isNotEmpty) {
          await cache.cacheTrucks(fresh.map((m) => Map<String, dynamic>.from(m)).toList());
        }
      } catch (e) {
        // silent
      }
    });

    if (trucks.isNotEmpty) return trucks;
    final fresh = await _supabaseService.getTrucks();
    if (fresh.isNotEmpty) {
      await cache.cacheTrucks(fresh.map((m) => Map<String, dynamic>.from(m)).toList());
    }
    return fresh;
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

    Future.microtask(() async {
      try {
        final fresh = await _supabaseService.getDrivers();
        if (fresh.isNotEmpty) {
          await cache.cacheDrivers(fresh.map((m) => Map<String, dynamic>.from(m)).toList());
        }
      } catch (e) {
        // silent
      }
    });

    if (drivers.isNotEmpty) return drivers;
    final fresh = await _supabaseService.getDrivers();
    if (fresh.isNotEmpty) {
      await cache.cacheDrivers(fresh.map((m) => Map<String, dynamic>.from(m)).toList());
    }
    return fresh;
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
