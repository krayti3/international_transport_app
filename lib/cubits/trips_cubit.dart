import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/trip_order.dart';
import '../../models/client.dart';
import '../../repositories/trip_repository.dart';
import '../../features/clients/repositories/client_repository.dart';
import '../../repositories/driver_repository.dart';
import '../../repositories/truck_repository.dart';

part 'trips_state.dart';

class TripsCubit extends Cubit<TripsState> {
  TripsCubit(
    this._tripRepository,
    this._clientRepository,
    this._driverRepository,
    this._truckRepository,
  ) : super(const TripsState()) {
    loadTrips();
    _tripOrdersSubscription = _tripRepository.getTripOrdersStream().listen((_) {
      if (!isClosed) loadTrips();
    });
  }

  final TripRepository _tripRepository;
  final ClientRepository _clientRepository;
  final DriverRepository _driverRepository;
  final TruckRepository _truckRepository;
  StreamSubscription<List<Map<String, dynamic>>>? _tripOrdersSubscription;

  Future<void> loadTrips() async {
    emit(state.copyWith(isLoading: true, isRefreshing: false, errorMessage: null));

    try {
      final cachedTrips = await _tripRepository.getCachedTripOrders();
      final cachedClients = await _clientRepository.getCachedClients();
      final cachedDrivers = await _driverRepository.getCachedDrivers();
      final cachedTrucks = await _truckRepository.getCachedTrucks();

      if (cachedTrips != null || cachedClients != null || cachedDrivers != null || cachedTrucks != null) {
        final trips = (cachedTrips ?? <Map<String, dynamic>>[]).sorted((a, b) => (b['id'] as int? ?? 0).compareTo(a['id'] as int? ?? 0));
        final List<Client> clients = cachedClients ?? <Client>[];
        final List<Map<String, dynamic>> drivers = cachedDrivers ?? <Map<String, dynamic>>[];
        final List<Map<String, dynamic>> trucks = cachedTrucks ?? <Map<String, dynamic>>[];

        final clientMap = <String, String>{for (final c in clients) c.id.toString(): c.name};
        final driverMap = <String, String>{for (final d in drivers) d['id'].toString(): d['name'] as String};
        final truckMap = <String, String>{for (final t in trucks) (t['id'] as int?)?.toString() ?? '': t['plate_number']?.toString() ?? t['plate']?.toString() ?? '—'};

        emit(state.copyWith(
          tripOrders: trips,
          clients: clients.map((c) => c.toMap()).toList(),
          drivers: drivers,
          trucks: trucks,
          clientMap: clientMap,
          driverMap: driverMap,
          truckMap: truckMap,
          isLoading: false,
          isRefreshing: true,
        ));
      }
    } catch (e) {
      debugPrint('Cache read error in loadTrips: $e');
    }

    try {
      final trips = await _tripRepository.getTripOrders();
      final clients = await _clientRepository.getClients();
      final drivers = await _driverRepository.getDrivers();
      final trucks = await _truckRepository.getTrucks();

      final clientMap = <String, String>{for (final c in clients) c.id.toString(): c.name};
      final driverMap = <String, String>{for (final d in drivers) d['id'].toString(): d['name'] as String};
      final truckMap = <String, String>{for (final t in trucks) t.id.toString(): t.plate};

      final sortedTrips = trips.sorted((a, b) => (b['id'] as int? ?? 0).compareTo(a['id'] as int? ?? 0)).toList();

      emit(state.copyWith(
        tripOrders: sortedTrips,
        clients: clients.map((c) => c.toMap()).toList(),
        drivers: drivers,
        trucks: trucks,
        clientMap: clientMap,
        driverMap: driverMap,
        truckMap: truckMap,
        isLoading: false,
        isRefreshing: false,
      ));
    } catch (e) {
      if (state.tripOrders.isEmpty) {
        emit(state.copyWith(isLoading: false, isRefreshing: false, errorMessage: e.toString()));
      } else {
        emit(state.copyWith(isRefreshing: false, errorMessage: e.toString()));
      }
    }
  }

  @override
  Future<void> close() async {
    await _tripOrdersSubscription?.cancel();
    return super.close();
  }

  String clientName(dynamic clientId) {
    final key = clientId?.toString();
    return state.clientMap[key] ?? 'غير محدد';
  }

  String driverName(dynamic driverId) {
    final key = driverId?.toString();
    return state.driverMap[key] ?? '—';
  }

  String truckPlate(dynamic truckId) {
    final key = truckId?.toString();
    return state.truckMap[key] ?? '—';
  }

  void updateTripInList(TripOrder updatedTrip) {
    if (state.tripOrders.isNotEmpty) {
      final updatedTrips = state.tripOrders.map((trip) {
        return trip['id'] == updatedTrip.id ? updatedTrip.toMap() : trip;
      }).toList();
      emit(state.copyWith(tripOrders: updatedTrips));
    }
  }
}
