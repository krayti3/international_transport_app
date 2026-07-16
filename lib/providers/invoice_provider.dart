import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/models/bank_account.dart';
import 'package:international_transport_app/services/calculation_engine.dart';

class InvoiceProvider extends ChangeNotifier {
  BankAccount? _selectedBankAccount;
  String _inputMode = 'HT';
  Decimal _tvaRate = Decimal.zero;
  InvoiceCalculation? _calculation;
  Decimal? _manualAmount;
  List<BankAccount> _bankAccounts = [];

  BankAccount? get selectedBankAccount => _selectedBankAccount;
  String get inputMode => _inputMode;
  Decimal get tvaRate => _tvaRate;
  InvoiceCalculation? get calculation => _calculation;
  Decimal? get manualAmount => _manualAmount;
  List<BankAccount> get bankAccounts => _bankAccounts;

  void setInputMode(String mode) {
    if (mode != 'HT' && mode != 'TTC') return;
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

  void setManualAmount(Decimal? amount) {
    _manualAmount = amount;
    _recalculate();
    notifyListeners();
  }

  void setBankAccounts(List<BankAccount> accounts) {
    _bankAccounts = accounts;
    notifyListeners();
  }

  void _recalculate() {
    if (_manualAmount == null || _tvaRate == Decimal.zero) {
      _calculation = null;
      return;
    }

    try {
      _calculation = CalculationEngine.calculate(
        amount: _manualAmount!,
        inputMode: _inputMode,
        tvaRate: _tvaRate,
      );
    } catch (e) {
      debugPrint('Calculation error: $e');
      _calculation = null;
    }
  }

  void reset() {
    _selectedBankAccount = null;
    _inputMode = 'HT';
    _tvaRate = Decimal.zero;
    _calculation = null;
    _manualAmount = null;
    _bankAccounts = [];
    notifyListeners();
  }
}
