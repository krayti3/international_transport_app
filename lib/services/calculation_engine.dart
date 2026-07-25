import 'package:decimal/decimal.dart';

class InvoiceCalculation {
  final Decimal htAmount;
  final Decimal tvaAmount;
  final Decimal ttcAmount;
  final Decimal tvaRate;
  final String inputMode; // 'HT' or 'TTC'

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
    if (inputMode == 'HT') {
      final ht = inputAmount;
      final tva = ht * (tvaRate / Decimal.fromInt(100)).toDecimal();
      final ttc = ht + tva;
      return InvoiceCalculation(
        htAmount: ht,
        tvaAmount: tva,
        ttcAmount: ttc,
        tvaRate: tvaRate,
        inputMode: inputMode,
      );
    } else if (inputMode == 'TTC') {
      final ttc = inputAmount;
      final ht = (ttc / (Decimal.one + (tvaRate / Decimal.fromInt(100)).toDecimal())).toDecimal();
      final tva = ht * (tvaRate / Decimal.fromInt(100)).toDecimal();
      return InvoiceCalculation(
        htAmount: ht,
        tvaAmount: tva,
        ttcAmount: ttc,
        tvaRate: tvaRate,
        inputMode: inputMode,
      );
    } else {
      throw ArgumentError('Invalid input mode: $inputMode');
    }
  }
}

class CalculationEngine {
  static InvoiceCalculation calculate({
    required Decimal amount,
    required String inputMode, // 'HT' or 'TTC'
    required Decimal tvaRate,
  }) {
    return InvoiceCalculation.fromInput(
      inputAmount: amount,
      inputMode: inputMode,
      tvaRate: tvaRate,
    );
  }

  static Decimal calculateTVA(Decimal htAmount, Decimal tvaRate) {
    return htAmount * (tvaRate / Decimal.fromInt(100)).toDecimal();
  }

  static Decimal calculateTTC(Decimal htAmount, Decimal tvaRate) {
    return htAmount + calculateTVA(htAmount, tvaRate);
  }

  static Decimal calculateHTFromTTC(Decimal ttcAmount, Decimal tvaRate) {
    return (ttcAmount / (Decimal.one + (tvaRate / Decimal.fromInt(100)).toDecimal())).toDecimal();
  }

  static Decimal roundToCurrency(Decimal amount, int decimals) {
    final factor = Decimal.parse(Decimal.fromInt(10).pow(decimals).toString());
    final scaled = amount * factor;
    final rounded = scaled.round();
    final roundedDecimal = Decimal.parse(rounded.toString());
    return Decimal.parse((roundedDecimal / factor).toString());
  }
}
