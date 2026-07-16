import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final double expenses;
  final double netProfit;

  const SimpleBarChart({super.key, required this.expenses, required this.netProfit});

  @override
  Widget build(BuildContext context) {
    final maxValue = expenses > netProfit ? expenses : netProfit;
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final expensesHeight = (expenses / safeMax).clamp(0.1, 1.0);
    final profitHeight = (netProfit / safeMax).clamp(0.1, 1.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              children: [
                Text('${expenses.toStringAsFixed(2)} DH', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  height: MediaQuery.of(context).size.height * 0.25 * expensesHeight,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('المصاريف', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                Text('${netProfit.toStringAsFixed(2)} DH', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  height: MediaQuery.of(context).size.height * 0.25 * profitHeight,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('صافي الأرباح', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
