part of 'clients_cubit.dart';

class ClientsState {
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final List<Client> clients;
  final List<Client> filteredClients;
  final String searchQuery;
  final String statusFilter;

  const ClientsState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.errorMessage,
    this.clients = const [],
    this.filteredClients = const [],
    this.searchQuery = '',
    this.statusFilter = 'all',
  });

  ClientsState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    List<Client>? clients,
    List<Client>? filteredClients,
    String? searchQuery,
    String? statusFilter,
  }) {
    return ClientsState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage ?? this.errorMessage,
      clients: clients ?? this.clients,
      filteredClients: filteredClients ?? this.filteredClients,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}
