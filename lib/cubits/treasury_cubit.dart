import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/treasury_repository.dart';
import '../models/treasury_transaction.dart';

part 'treasury_state.dart';

class TreasuryCubit extends Cubit<TreasuryState> {
  TreasuryCubit(this._repository) : super(const TreasuryState()) {
    _listenToTreasuryStream();
    refresh();
  }

  final TreasuryRepository _repository;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  void _listenToTreasuryStream() {
    _subscription = _repository.treasuryStream().listen((transactions) {
      _updateBalances(transactions);
    });
  }

  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await Future.wait([
        _loadCashBoxes(),
        _loadTransactions(),
      ]);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _loadCashBoxes() async {
    final boxes = await _repository.getCashBoxes();
    final balances = await _repository.getCashBoxBalances();
    emit(state.copyWith(
      cashBoxes: boxes,
      boxBalances: balances,
      isBoxesLoading: false,
    ));
  }

  Future<void> _loadTransactions() async {
    final selectedId = state.selectedCashBoxId;
    final transactions = await _repository.getTreasuryTransactions(
      cashBoxId: selectedId,
    );
    final mapped = transactions.map(TreasuryTransaction.fromMap).toList();
    emit(state.copyWith(
      transactions: mapped,
      isLoading: false,
    ));
  }

  Future<void> _updateBalances(List<Map<String, dynamic>> transactions) async {
    final selectedId = state.selectedCashBoxId;
    final filtered = selectedId != null
        ? transactions.where((t) {
            final cid = t['cash_box_id'] as int?;
            final related = t['related_cash_box_id'] as int?;
            return cid == selectedId || related == selectedId;
          }).toList()
        : transactions;

    final mapped = filtered.map(TreasuryTransaction.fromMap).toList();
    emit(state.copyWith(transactions: mapped));
  }

  void onCashBoxChanged(String? value) {
    emit(state.copyWith(
      selectedCashBoxId: value != null ? int.tryParse(value) : null,
    ));
    refresh();
  }

  void onCurrencyChanged(String currency) {
    emit(state.copyWith(selectedCurrency: currency));
  }

  Future<void> addTransaction({
    required double amount,
    required String type,
    required String description,
    int? cashBoxId,
    String currency = 'MAD',
  }) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _repository.addTreasuryTransaction(
        amount,
        type,
        description,
        cashBoxId: cashBoxId,
        currency: currency,
      );
      await refresh();
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  Future<void> addTransfer({
    required double amount,
    required int fromCashBoxId,
    required int toCashBoxId,
    String description = 'تحويل بين الصناديق',
    String currency = 'MAD',
  }) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _repository.addTransfer(
        amount: amount,
        fromCashBoxId: fromCashBoxId,
        toCashBoxId: toCashBoxId,
        description: description,
        currency: currency,
      );
      await refresh();
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
