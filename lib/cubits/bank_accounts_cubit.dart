import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:international_transport_app/models/bank_account.dart';
import '../../repositories/bank_account_repository.dart';

part 'bank_accounts_state.dart';

class BankAccountsCubit extends Cubit<BankAccountsState> {
  BankAccountsCubit(this._repository) : super(const BankAccountsState()) {
    loadAccounts();
  }

  final BankAccountRepository _repository;

  Future<void> loadAccounts() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final accounts = await _repository.getBankAccounts();
      emit(state.copyWith(
        accounts: accounts,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> addAccount(Map<String, dynamic> data) async {
    try {
      await _repository.addBankAccount(data);
      await loadAccounts();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> updateAccount(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateBankAccount(id, data);
      await loadAccounts();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      await _repository.deleteBankAccount(id);
      await loadAccounts();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
