part of 'treasury_cubit.dart';

class TreasuryState {
  final bool isLoading;
  final bool isBoxesLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> cashBoxes;
  final Map<int, Map<String, double>> boxBalances;
  final List<TreasuryTransaction> transactions;
  final int? selectedCashBoxId;
  final String selectedCurrency;

  const TreasuryState({
    this.isLoading = true,
    this.isBoxesLoading = true,
    this.errorMessage,
    this.cashBoxes = const [],
    this.boxBalances = const {},
    this.transactions = const [],
    this.selectedCashBoxId,
    this.selectedCurrency = 'MAD',
  });

  TreasuryState copyWith({
    bool? isLoading,
    bool? isBoxesLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? cashBoxes,
    Map<int, Map<String, double>>? boxBalances,
    List<TreasuryTransaction>? transactions,
    int? selectedCashBoxId,
    String? selectedCurrency,
  }) {
    return TreasuryState(
      isLoading: isLoading ?? this.isLoading,
      isBoxesLoading: isBoxesLoading ?? this.isBoxesLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      cashBoxes: cashBoxes ?? this.cashBoxes,
      boxBalances: boxBalances ?? this.boxBalances,
      transactions: transactions ?? this.transactions,
      selectedCashBoxId: selectedCashBoxId ?? this.selectedCashBoxId,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
    );
  }
}
