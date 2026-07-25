import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../models/bank_account.dart';
import '../services/calculation_engine.dart';

class InvoiceProvider extends ChangeNotifier {
  BankAccount? _selectedBankAccount;
  String _inputMode = 'HT';
  Decimal _tvaRate = Decimal.zero;
  InvoiceCalculation? _calculation;
  Decimal _inputAmount = Decimal.zero;

  // Getters
  BankAccount? get selectedBankAccount => _selectedBankAccount;
  String get inputMode => _inputMode;
  Decimal get tvaRate => _tvaRate;
  InvoiceCalculation? get calculation => _calculation;
  Decimal get inputAmount => _inputAmount;

  // Methods
  void setInputMode(String mode) {
    _inputMode = mode;
    _recalculate();
    notifyListeners();
  }

  void setBankAccount(BankAccount? account) {
    _selectedBankAccount = account;
    notifyListeners();
  }

  void setTvaRate(Decimal rate) {
    _tvaRate = rate;
    _recalculate();
    notifyListeners();
  }

  void setInputAmount(Decimal amount) {
    _inputAmount = amount;
    _recalculate();
    notifyListeners();
  }

  void _recalculate() {
    if (_inputAmount > Decimal.zero && _tvaRate >= Decimal.zero) {
      _calculation = CalculationEngine.calculate(
        amount: _inputAmount,
        inputMode: _inputMode,
        tvaRate: _tvaRate,
      );
    } else {
      _calculation = null;
    }
    notifyListeners();
  }
}