part of 'customer_detail_cubit.dart';

class CustomerDetailState {
  final bool isLoading;
  final String? errorMessage;
  final List<Invoice> invoices;
  final List<BankAccount> bankAccounts;
  final List<Map<String, dynamic>> cashBoxes;
  final String currentFilter;

  const CustomerDetailState({
    this.isLoading = true,
    this.errorMessage,
    this.invoices = const [],
    this.bankAccounts = const [],
    this.cashBoxes = const [],
    this.currentFilter = 'all',
  });

  CustomerDetailState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Invoice>? invoices,
    List<BankAccount>? bankAccounts,
    List<Map<String, dynamic>>? cashBoxes,
    String? currentFilter,
  }) {
    return CustomerDetailState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      invoices: invoices ?? this.invoices,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      cashBoxes: cashBoxes ?? this.cashBoxes,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }

  List<Invoice> get filteredInvoices {
    if (currentFilter == 'all') return invoices;
    return invoices.where((inv) => inv.status == currentFilter).toList();
  }

  Decimal get totalDue {
    Decimal total = Decimal.zero;
    for (final inv in invoices) {
      total += inv.totalAmount - (inv.paidAmount ?? Decimal.zero);
    }
    return total;
  }

  int get pendingCount {
    return invoices.where((inv) => inv.status != 'paid').length;
  }
}
