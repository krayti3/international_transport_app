part of 'drivers_cubit.dart';

class DriversState {
  final bool isLoading;
  final String? errorMessage;
  final List<Driver> drivers;
  final List<Driver> filteredDrivers;
  final String searchQuery;
  final String statusFilter;

  const DriversState({
    this.isLoading = true,
    this.errorMessage,
    this.drivers = const [],
    this.filteredDrivers = const [],
    this.searchQuery = '',
    this.statusFilter = 'all',
  });

  DriversState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Driver>? drivers,
    List<Driver>? filteredDrivers,
    String? searchQuery,
    String? statusFilter,
  }) {
    return DriversState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      drivers: drivers ?? this.drivers,
      filteredDrivers: filteredDrivers ?? this.filteredDrivers,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}
