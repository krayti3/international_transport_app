import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:international_transport_app/models/trailer.dart';
import '../../repositories/trailer_repository.dart';

part 'trailers_state.dart';

class TrailersCubit extends Cubit<TrailersState> {
  TrailersCubit(this._repository) : super(const TrailersState()) {
    loadTrailers();
  }

  final TrailerRepository _repository;

  Future<void> loadTrailers() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final trailers = await _repository.getTrailers();
      emit(state.copyWith(
        trailers: trailers,
        filteredTrailers: _applyFilters(trailers, state.searchQuery, state.statusFilter),
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void onSearchChanged(String query) {
    final filtered = _applyFilters(state.trailers, query, state.statusFilter);
    emit(state.copyWith(searchQuery: query, filteredTrailers: filtered));
  }

  void onStatusFilterChanged(String filter) {
    final filtered = _applyFilters(state.trailers, state.searchQuery, filter);
    emit(state.copyWith(statusFilter: filter, filteredTrailers: filtered));
  }

  List<Trailer> _applyFilters(List<Trailer> trailers, String query, String statusFilter) {
    final lowerQuery = query.trim().toLowerCase();
    return trailers.where((trailer) {
      if (statusFilter == 'active' && trailer.status != 'active') return false;
      if (statusFilter == 'inactive' && trailer.status == 'active') return false;
      if (lowerQuery.isEmpty) return true;
      return trailer.plate.toLowerCase().contains(lowerQuery) ||
          trailer.type.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Future<void> addTrailer(Map<String, dynamic> data) async {
    try {
      await _repository.addTrailer(data);
      await loadTrailers();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> updateTrailer(int id, Map<String, dynamic> data) async {
    try {
      await _repository.updateTrailer(id, data);
      await loadTrailers();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> deleteTrailer(int id) async {
    try {
      await _repository.deleteTrailer(id);
      await loadTrailers();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
