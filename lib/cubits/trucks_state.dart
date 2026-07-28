part of 'trucks_cubit.dart';

class TrucksState {
  final bool isLoading;
  final String? errorMessage;
  final List<Truck> trucks;
  final List<Truck> filteredTrucks;
  final List<Trailer> trailers;
  final String searchQuery;
  final String? selectedStatus;

  const TrucksState({
    this.isLoading = true,
    this.errorMessage,
    this.trucks = const [],
    this.filteredTrucks = const [],
    this.trailers = const [],
    this.searchQuery = '',
    this.selectedStatus = 'active',
  });

  TrucksState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Truck>? trucks,
    List<Truck>? filteredTrucks,
    List<Trailer>? trailers,
    String? searchQuery,
    String? selectedStatus,
  }) {
    return TrucksState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      trucks: trucks ?? this.trucks,
      filteredTrucks: filteredTrucks ?? this.filteredTrucks,
      trailers: trailers ?? this.trailers,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }
}