import 'package:flutter/material.dart';

class ExpenseRow extends StatelessWidget {
  final String title;
  final double amount;

  const ExpenseRow({super.key, required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            Text(
              '${amount.toStringAsFixed(2)} DH',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
