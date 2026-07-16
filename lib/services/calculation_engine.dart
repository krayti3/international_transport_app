import 'dart:math';

import 'package:decimal/decimal.dart';

class InvoiceCalculation {
  final Decimal htAmount;
  final Decimal tvaAmount;
  final Decimal ttcAmount;
  final Decimal tvaRate;
  final String inputMode;

  InvoiceCalculation({
    required this.htAmount,
    required this.tvaAmount,
    required this.ttcAmount,
    required this.tvaRate,
    required this.inputMode,
  });

  factory InvoiceCalculation.fromInput({
    required Decimal inputAmount,
    required String inputMode,
    required Decimal tvaRate,
  }) {
    return CalculationEngine.calculate(
      amount: inputAmount,
      inputMode: inputMode,
      tvaRate: tvaRate,
    );
  }

  @override
  String toString() {
    return 'HT: $htAmount, TVA: $tvaAmount, TTC: $ttcAmount';
  }
}

class CalculationEngine {
  static InvoiceCalculation calculate({
    required Decimal amount,
    required String inputMode,
    required Decimal tvaRate,
  }) {
    if (inputMode != 'HT' && inputMode != 'TTC') {
      throw ArgumentError('Invalid input mode: $inputMode. Must be HT or TTC.');
    }

    final amountD = amount.toDouble();
    final rateD = tvaRate.toDouble();

    double htD;
    double tvaD;
    double ttcD;

    if (inputMode == 'HT') {
      htD = amountD;
      tvaD = _calculateTVA(htD, rateD);
      ttcD = _calculateTTC(htD, rateD);
    } else {
      ttcD = amountD;
      htD = _calculateHTFromTTC(ttcD, rateD);
      tvaD = _calculateTVA(htD, rateD);
    }

    return InvoiceCalculation(
      htAmount: Decimal.parse(htD.toString()),
      tvaAmount: Decimal.parse(tvaD.toString()),
      ttcAmount: Decimal.parse(ttcD.toString()),
      tvaRate: tvaRate,
      inputMode: inputMode,
    );
  }

  static double _calculateTVA(double htAmount, double tvaRate) {
    return htAmount * tvaRate / 100.0;
  }

  static double _calculateTTC(double htAmount, double tvaRate) {
    return htAmount + _calculateTVA(htAmount, tvaRate);
  }

  static double _calculateHTFromTTC(double ttcAmount, double tvaRate) {
    final divisor = 1.0 + tvaRate / 100.0;
    return ttcAmount / divisor;
  }

  static Decimal roundToCurrency(Decimal amount, {int decimals = 2}) {
    final factor = pow(10.0, decimals).toDouble();
    final multiplied = amount.toDouble() * factor;
    final rounded = multiplied.round().toDouble();
    return Decimal.parse((rounded / factor).toString());
  }
}
