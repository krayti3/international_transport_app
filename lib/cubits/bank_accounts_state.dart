part of 'bank_accounts_cubit.dart';

class BankAccountsState {
  final bool isLoading;
  final String? errorMessage;
  final List<BankAccount> accounts;

  const BankAccountsState({
    this.isLoading = true,
    this.errorMessage,
    this.accounts = const [],
  });

  BankAccountsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<BankAccount>? accounts,
  }) {
    return BankAccountsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      accounts: accounts ?? this.accounts,
    );
  }
}
