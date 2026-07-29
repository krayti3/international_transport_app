import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:international_transport_app/models/truck.dart';
import 'package:international_transport_app/models/trailer.dart';
import '../../repositories/truck_repository.dart';
import '../../repositories/trailer_repository.dart';

part 'trucks_state.dart';

class TrucksCubit extends Cubit<TrucksState> {
  TrucksCubit(this._truckRepository, this._trailerRepository)
      : super(const TrucksState()) {
    loadTrucks();
  }

  final TruckRepository _truckRepository;
  final TrailerRepository _trailerRepository;

  Future<void> loadTrucks() async {
    emit(state.copyWith(isLoading: true, isRefreshing: false, errorMessage: null));

    try {
      final cachedTrucks = await _truckRepository.getCachedTrucks();
      final cachedTrailers = await _trailerRepository.getCachedTrailers();

      if (cachedTrucks != null || cachedTrailers.isNotEmpty) {
        final List<Truck> trucks;
        if (cachedTrucks != null) {
          trucks = cachedTrucks.map((t) => Truck.fromMap(t)).toList();
        } else {
          trucks = <Truck>[];
        }
        final List<Trailer> trailers = cachedTrailers;

        final sortedTrucks = trucks
            .sorted((a, b) => a.plate.toLowerCase().compareTo(b.plate.toLowerCase()))
            .toList();

        emit(state.copyWith(
          trucks: sortedTrucks,
          trailers: trailers,
          filteredTrucks: _applyFilters(sortedTrucks, state.searchQuery, state.selectedStatus),
          isLoading: false,
          isRefreshing: true,
        ));
      }
    } catch (e) {
      debugPrint('Cache read error in loadTrucks: $e');
    }

    try {
      final trucks = await _truckRepository.getTrucks();
      final trailers = await _trailerRepository.getTrailers();

      final sortedTrucks = trucks
          .sorted((a, b) => a.plate.toLowerCase().compareTo(b.plate.toLowerCase()))
          .toList();

      emit(state.copyWith(
        trucks: sortedTrucks,
        trailers: trailers,
        filteredTrucks: _applyFilters(sortedTrucks, state.searchQuery, state.selectedStatus),
        isLoading: false,
        isRefreshing: false,
      ));
    } catch (e) {
      if (state.trucks.isEmpty) {
        emit(state.copyWith(isLoading: false, isRefreshing: false, errorMessage: e.toString()));
      } else {
        emit(state.copyWith(isRefreshing: false, errorMessage: e.toString()));
      }
    }
  }

  void onSearchChanged(String query) {
    final filtered = _applyFilters(state.trucks, query, state.selectedStatus);
    emit(state.copyWith(searchQuery: query, filteredTrucks: filtered));
  }

  void onStatusFilterChanged(String? status) {
    emit(state.copyWith(selectedStatus: status));
    final filtered = _applyFilters(state.trucks, state.searchQuery, status ?? 'all');
    emit(state.copyWith(filteredTrucks: filtered));
  }

  List<Truck> _applyFilters(List<Truck> trucks, String query, String? statusFilter) {
    final lowerQuery = query.trim().toLowerCase();
    return trucks.where((truck) {
      final matchesStatus = statusFilter == null ||
          statusFilter == 'all' ||
          truck.status == statusFilter;
      if (!matchesStatus) return false;
      if (lowerQuery.isEmpty) return true;
      final plate = truck.plate.toLowerCase();
      final model = truck.model.toLowerCase();
      final location = (truck.currentLocation ?? '').toLowerCase();
      return plate.contains(lowerQuery) ||
          model.contains(lowerQuery) ||
          location.contains(lowerQuery);
    }).toList();
  }

  Future<void> addTruck(Map<String, dynamic> data) async {
    try {
      await _truckRepository.addTruck(data);
      await loadTrucks();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> updateTruck(int id, Map<String, dynamic> data) async {
    try {
      await _truckRepository.updateTruck(id, data);
      await loadTrucks();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> deleteTruck(int id) async {
    try {
      await _truckRepository.deleteTruck(id);
      await loadTrucks();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
