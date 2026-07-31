part of 'invoices_cubit.dart';

class InvoicesState {
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final List<Invoice> allInvoices;
  final List<Invoice> filteredInvoices;
  final Map<String, String> clientNames;
  final bool tvaEnabled;
  final double tvaPercentage;
  final String currentFilter;

  const InvoicesState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.errorMessage,
    this.allInvoices = const [],
    this.filteredInvoices = const [],
    this.clientNames = const {},
    this.tvaEnabled = true,
    this.tvaPercentage = 0.0,
    this.currentFilter = 'all',
  });

  InvoicesState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    List<Invoice>? allInvoices,
    List<Invoice>? filteredInvoices,
    Map<String, String>? clientNames,
    bool? tvaEnabled,
    double? tvaPercentage,
    String? currentFilter,
  }) {
    return InvoicesState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage ?? this.errorMessage,
      allInvoices: allInvoices ?? this.allInvoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      clientNames: clientNames ?? this.clientNames,
      tvaEnabled: tvaEnabled ?? this.tvaEnabled,
      tvaPercentage: tvaPercentage ?? this.tvaPercentage,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }
}
