part of 'trailers_cubit.dart';

class TrailersState {
  final bool isLoading;
  final String? errorMessage;
  final List<Trailer> trailers;
  final List<Trailer> filteredTrailers;
  final String searchQuery;
  final String statusFilter;

  const TrailersState({
    this.isLoading = true,
    this.errorMessage,
    this.trailers = const [],
    this.filteredTrailers = const [],
    this.searchQuery = '',
    this.statusFilter = 'all',
  });

  TrailersState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Trailer>? trailers,
    List<Trailer>? filteredTrailers,
    String? searchQuery,
    String? statusFilter,
  }) {
    return TrailersState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      trailers: trailers ?? this.trailers,
      filteredTrailers: filteredTrailers ?? this.filteredTrailers,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}
