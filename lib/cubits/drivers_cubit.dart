import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:international_transport_app/models/driver.dart';
import '../../repositories/driver_repository.dart';

part 'drivers_state.dart';

class DriversCubit extends Cubit<DriversState> {
  DriversCubit(this._repository) : super(const DriversState()) {
    loadDrivers();
  }

  final DriverRepository _repository;

  Future<void> loadDrivers() async {
    emit(state.copyWith(isLoading: true, isRefreshing: false, errorMessage: null));

    try {
      final cachedDrivers = await _repository.getCachedDrivers();
      if (cachedDrivers != null) {
        final drivers = cachedDrivers.map((d) => Driver(
          id: d['id'] as int?,
          name: d['name']?.toString() ?? '',
          phone: d['phone']?.toString() ?? '',
          license: d['license']?.toString() ?? '',
          status: d['status']?.toString() ?? 'active',
          baseSalary: (d['base_salary'] as num?)?.toDouble() ?? 0.0,
          bonusPercentage: (d['bonus_percentage'] as num?)?.toDouble() ?? 0.0,
          defaultTruckId: d['default_truck_id'] as int?,
          visaNumber: d['visa_number']?.toString(),
          visaExpiryDate: d['visa_expiry_date'] != null ? DateTime.tryParse(d['visa_expiry_date'].toString()) : null,
          hasValidVisa: (d['has_valid_visa'] as bool?) ?? false,
        )).toList();

        drivers.sort((a, b) {
          final aStatus = a.status == 'active' ? 0 : 1;
          final bStatus = b.status == 'active' ? 0 : 1;
          return aStatus.compareTo(bStatus);
        });

        emit(state.copyWith(
          drivers: drivers,
          filteredDrivers: _applyFilters(drivers, state.searchQuery, state.statusFilter),
          isLoading: false,
          isRefreshing: true,
        ));
      }
    } catch (e) {
      debugPrint('Cache read error in loadDrivers: $e');
    }

    try {
      final rawDrivers = await _repository.getDrivers();
      final drivers = rawDrivers.map((d) => Driver(
        id: d['id'] as int?,
        name: d['name']?.toString() ?? '',
        phone: d['phone']?.toString() ?? '',
        license: d['license']?.toString() ?? '',
        status: d['status']?.toString() ?? 'active',
        baseSalary: (d['base_salary'] as num?)?.toDouble() ?? 0.0,
        bonusPercentage: (d['bonus_percentage'] as num?)?.toDouble() ?? 0.0,
        defaultTruckId: d['default_truck_id'] as int?,
        visaNumber: d['visa_number']?.toString(),
        visaExpiryDate: d['visa_expiry_date'] != null ? DateTime.tryParse(d['visa_expiry_date'].toString()) : null,
        hasValidVisa: (d['has_valid_visa'] as bool?) ?? false,
      )).toList();

      drivers.sort((a, b) {
        final aStatus = a.status == 'active' ? 0 : 1;
        final bStatus = b.status == 'active' ? 0 : 1;
        return aStatus.compareTo(bStatus);
      });

      emit(state.copyWith(
        drivers: drivers,
        filteredDrivers: _applyFilters(drivers, state.searchQuery, state.statusFilter),
        isLoading: false,
        isRefreshing: false,
      ));
    } catch (e) {
      if (state.drivers.isEmpty) {
        emit(state.copyWith(isLoading: false, isRefreshing: false, errorMessage: e.toString()));
      } else {
        emit(state.copyWith(isRefreshing: false, errorMessage: e.toString()));
      }
    }
  }

  void onSearchChanged(String query) {
    final filtered = _applyFilters(state.drivers, query, state.statusFilter);
    emit(state.copyWith(searchQuery: query, filteredDrivers: filtered));
  }

  void onStatusFilterChanged(String filter) {
    final filtered = _applyFilters(state.drivers, state.searchQuery, filter);
    emit(state.copyWith(statusFilter: filter, filteredDrivers: filtered));
  }

  List<Driver> _applyFilters(List<Driver> drivers, String query, String statusFilter) {
    final lowerQuery = query.trim().toLowerCase();
    return drivers.where((driver) {
      if (statusFilter == 'active' && driver.status != 'active') return false;
      if (statusFilter == 'inactive' && driver.status == 'active') return false;
      if (lowerQuery.isEmpty) return true;
      return driver.name.toLowerCase().contains(lowerQuery) ||
          driver.phone.toLowerCase().contains(lowerQuery) ||
          driver.license.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Future<void> addDriver(Map<String, dynamic> data) async {
    try {
      await _repository.addDriver(data);
      await loadDrivers();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> updateDriver(int id, Map<String, dynamic> data) async {
    try {
      await _repository.updateDriver(id, data);
      await loadDrivers();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> deleteDriver(int id) async {
    try {
      await _repository.deleteDriver(id);
      await loadDrivers();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> updateDriverVisa(String driverId, String visaNumber, DateTime expiryDate) async {
    try {
      await _repository.updateDriverVisa(driverId, visaNumber, expiryDate);
      await loadDrivers();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
