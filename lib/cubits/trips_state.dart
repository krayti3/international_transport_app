part of 'trips_cubit.dart';

class TripsState {
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final List<Map<String, dynamic>> tripOrders;
  final List<Map<String, dynamic>> clients;
  final List<dynamic> drivers;
  final List<dynamic> trucks;
  final Map<String, String> clientMap;
  final Map<String, String> driverMap;
  final Map<String, String> truckMap;

  const TripsState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.errorMessage,
    this.tripOrders = const [],
    this.clients = const [],
    this.drivers = const [],
    this.trucks = const [],
    this.clientMap = const {},
    this.driverMap = const {},
    this.truckMap = const {},
  });

  TripsState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    List<Map<String, dynamic>>? tripOrders,
    List<Map<String, dynamic>>? clients,
    List<dynamic>? drivers,
    List<dynamic>? trucks,
    Map<String, String>? clientMap,
    Map<String, String>? driverMap,
    Map<String, String>? truckMap,
  }) {
    return TripsState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage ?? this.errorMessage,
      tripOrders: tripOrders ?? this.tripOrders,
      clients: clients ?? this.clients,
      drivers: drivers ?? this.drivers,
      trucks: trucks ?? this.trucks,
      clientMap: clientMap ?? this.clientMap,
      driverMap: driverMap ?? this.driverMap,
      truckMap: truckMap ?? this.truckMap,
    );
  }
}
