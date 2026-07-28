part of 'invoices_cubit.dart';

class InvoicesState {
  final bool isLoading;
  final String? errorMessage;
  final List<Invoice> allInvoices;
  final List<Invoice> filteredInvoices;
  final Map<String, String> clientNames;
  final bool tvaEnabled;
  final double tvaPercentage;
  final String currentFilter;

  const InvoicesState({
    this.isLoading = true,
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
      errorMessage: errorMessage,
      allInvoices: allInvoices ?? this.allInvoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      clientNames: clientNames ?? this.clientNames,
      tvaEnabled: tvaEnabled ?? this.tvaEnabled,
      tvaPercentage: tvaPercentage ?? this.tvaPercentage,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }
}
