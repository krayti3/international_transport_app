import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  }

  final TripRepository _tripRepository;
  final ClientRepository _clientRepository;
  final DriverRepository _driverRepository;
  final TruckRepository _truckRepository;

  Future<void> loadTrips() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final trips = await _tripRepository.getTripOrders();
      final clients = await _clientRepository.getClients();
      final drivers = await _driverRepository.getDrivers();
      final trucks = await _truckRepository.getTrucks();

      final clientMap = <String, String>{for (final c in clients) c.id.toString(): c.name};
      final driverMap = <String, String>{for (final d in drivers) d['id'].toString(): d['name'] as String};
      final truckMap = <String, String>{for (final t in trucks) t.id.toString(): t.plate};

      final sortedTrips = trips
          .sorted((a, b) => (b['id'] as int? ?? 0).compareTo(a['id'] as int? ?? 0))
          .toList();

      emit(state.copyWith(
        tripOrders: sortedTrips,
        clients: clients.map((c) => c.toMap()).toList(),
        drivers: drivers,
        trucks: trucks,
        clientMap: clientMap,
        driverMap: driverMap,
        truckMap: truckMap,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
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
}
