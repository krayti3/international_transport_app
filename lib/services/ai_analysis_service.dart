import 'package:intl/intl.dart';

class PredictionResult {
  final double predictedValue;
  final double confidence;
  final String trend; // 'up' | 'down' | 'stable'
  final String descriptionAr;

  const PredictionResult({
    required this.predictedValue,
    required this.confidence,
    required this.trend,
    required this.descriptionAr,
  });
}

class InsightItem {
  final String titleAr;
  final String descriptionAr;
  final String severity; // 'info' | 'warning' | 'alert' | 'success'
  final String? suggestionAr;

  const InsightItem({
    required this.titleAr,
    required this.descriptionAr,
    required this.severity,
    this.suggestionAr,
  });
}

class ProfitForecast {
  final double predictedProfit;
  final double confidence;
  final List<Map<String, dynamic>> monthlyHistory;
  final List<Map<String, dynamic>> monthlyPrediction;
  final String trendAr;

  const ProfitForecast({
    required this.predictedProfit,
    required this.confidence,
    required this.monthlyHistory,
    required this.monthlyPrediction,
    required this.trendAr,
  });
}

class AiReportSummary {
  final ProfitForecast profitForecast;
  final List<InsightItem> insights;
  final double currentMonthRevenue;
  final double currentMonthExpenses;
  final double currentMonthProfit;
  final double predictedNextMonthProfit;
  final double averageMonthlyProfit;
  final double expenseGrowthRate;
  final double revenueGrowthRate;
  final int totalTripsThisMonth;
  final int totalTripsLastMonth;
  final String overallHealthAr;
  final SeasonalityResult? seasonality;
  final List<String> recommendations;

  const AiReportSummary({
    required this.profitForecast,
    required this.insights,
    required this.currentMonthRevenue,
    required this.currentMonthExpenses,
    required this.currentMonthProfit,
    required this.predictedNextMonthProfit,
    required this.averageMonthlyProfit,
    required this.expenseGrowthRate,
    required this.revenueGrowthRate,
    required this.totalTripsThisMonth,
    required this.totalTripsLastMonth,
    required this.overallHealthAr,
    this.seasonality,
    this.recommendations = const [],
  });
}

class SeasonalityResult {
  final Map<String, dynamic> bestMonth;
  final Map<String, dynamic> worstMonth;
  final String trend;
  final List<Map<String, dynamic>> forecast;

  const SeasonalityResult({
    required this.bestMonth,
    required this.worstMonth,
    required this.trend,
    required this.forecast,
  });
}

class AiAnalysisService {
  static const int _historyMonths = 6;

  static ProfitForecast forecastProfit(List<Map<String, dynamic>> monthlyData) {
    if (monthlyData.length < 2) {
      final current = monthlyData.isNotEmpty ? (monthlyData.last['profit'] as double?) ?? 0.0 : 0.0;
      return ProfitForecast(
        predictedProfit: current,
        confidence: 0.3,
        monthlyHistory: monthlyData,
        monthlyPrediction: const [],
        trendAr: 'غير مؤكد',
      );
    }

    final pairs = <List<double>>[];
    for (var i = 0; i < monthlyData.length; i++) {
      final profit = (monthlyData[i]['profit'] as double?) ?? 0.0;
      pairs.add([i.toDouble(), profit]);
    }

    final n = pairs.length.toDouble();
    final sumX = pairs.fold<double>(0.0, (sum, p) => sum + p[0]);
    final sumY = pairs.fold<double>(0.0, (sum, p) => sum + p[1]);
    final sumXY = pairs.fold<double>(0.0, (sum, p) => sum + p[0] * p[1]);
    final sumX2 = pairs.fold<double>(0.0, (sum, p) => sum + p[0] * p[0]);

    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) {
      return ProfitForecast(
        predictedProfit: sumY / n,
        confidence: 0.4,
        monthlyHistory: monthlyData,
        monthlyPrediction: const [],
        trendAr: 'مستقر',
      );
    }

    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;

    final nextIndex = n;
    final predicted = slope * nextIndex + intercept;
    final predictedClamped = predicted < 0 ? 0.0 : predicted;

    final lastProfit = monthlyData.last['profit'] as double? ?? 0.0;
    final diff = predictedClamped - lastProfit;
    final changePct = lastProfit != 0 ? (diff / lastProfit.abs()) : 0.0;

    String trendAr;
    if (changePct > 0.05) {
      trendAr = 'تصاعدي';
    } else if (changePct < -0.05) {
      trendAr = 'تنازلي';
    } else {
      trendAr = 'مستقر';
    }

    final predictionRow = {
      'month': 'الشهر القادم',
      'profit': predictedClamped,
      'isPrediction': true,
    };

    final sumSquaredError = pairs.fold<double>(0.0, (sum, p) {
      final predicted = slope * p[0] + intercept;
      final actual = p[1];
      return sum + (predicted - actual) * (predicted - actual);
    });
    final meanSquaredError = sumSquaredError / n;
    final variance = monthlyData.map((m) {
      final p = (m['profit'] as double?) ?? 0.0;
      final mean = sumY / n;
      return (p - mean) * (p - mean);
    }).fold<double>(0.0, (sum, v) => sum + v) / n;

    final confidence = variance > 0
        ? (1.0 - (meanSquaredError / (variance == 0 ? 1 : variance))).clamp(0.0, 0.95)
        : 0.5;

    return ProfitForecast(
      predictedProfit: predictedClamped,
      confidence: confidence,
      monthlyHistory: monthlyData,
      monthlyPrediction: [predictionRow],
      trendAr: trendAr,
    );
  }

  static List<InsightItem> generateInsights({
    required List<Map<String, dynamic>> monthlyData,
    required double currentRevenue,
    required double currentExpenses,
    required double predictedNextProfit,
    required double averageMonthlyProfit,
    required double revenueGrowthRate,
    required double expenseGrowthRate,
    required int currentTrips,
    required int previousTrips,
    required List<Map<String, dynamic>> expensesByCategory,
    required double outstandingInvoices,
  }) {
    final insights = <InsightItem>[];

    if (monthlyData.length >= 2) {
      final lastProfit = monthlyData.last['profit'] as double? ?? 0.0;
      final prevProfit = monthlyData.length >= 2
          ? (monthlyData[monthlyData.length - 2]['profit'] as double? ?? 0.0)
          : lastProfit;

      if (prevProfit != 0 && (lastProfit - prevProfit).abs() / prevProfit > 0.3) {
        final direction = lastProfit > prevProfit ? 'ارتفع' : 'انخفض';
        final changePct = ((lastProfit - prevProfit).abs() / prevProfit * 100).toInt();
        insights.add(InsightItem(
          titleAr: 'تغير كبير في الأرباح',
          descriptionAr: 'صافي الربح الشهري $direction بنسبة $changePct% مقارنة بالشهر السابق.',
          severity: lastProfit > prevProfit ? 'success' : 'warning',
          suggestionAr: lastProfit > prevProfit
              ? 'استمر في الاستراتيجية الحالية.'
              : 'راجع المصاريف وكفاءة الرحلات.',
        ));
      }
    }

    if (currentExpenses > currentRevenue && currentRevenue > 0) {
      insights.add(InsightItem(
        titleAr: 'تنبيه: مصاريف تفوق الإيرادات',
        descriptionAr: 'المصاريف الحالية تفوق الإيرادات بنسبة ${((currentExpenses - currentRevenue) / currentRevenue * 100).toInt()}%.',
        severity: 'alert',
        suggestionAr: 'تقليل المصاريف غير الضرورية أو زيادة عدد الرحلات.',
      ));
    }

    if (outstandingInvoices > 0) {
      final ratio = currentRevenue > 0 ? (outstandingInvoices / currentRevenue * 100) : 0.0;
      insights.add(InsightItem(
        titleAr: 'فواتير معلقة مرتفعة',
        descriptionAr: 'العمليات غير المسددة تشكل ${ratio.toInt()}% من الإيرادات الحالية.',
        severity: ratio > 30 ? 'alert' : 'warning',
        suggestionAr: ratio > 30
            ? 'تابع تحصيل الفواتير المتأخرة بجدية.'
            : 'تابع تحصيل الفواتير بشكل دوري.',
      ));
    }

    if (currentTrips > 0 && previousTrips > 0) {
      final tripsChange = ((currentTrips - previousTrips) / previousTrips * 100).toInt();
      if (tripsChange > 20) {
        insights.add(InsightItem(
          titleAr: 'نمو في عدد الرحلات',
          descriptionAr: 'عدد الرحلات الحالي أعلى من الشهر السابق بنسبة $tripsChange%.',
          severity: 'success',
          suggestionAr: 'تأكد من قدرة الأسطول على مواكبة الطلب المتزايد.',
        ));
      } else if (tripsChange < -20) {
        insights.add(InsightItem(
          titleAr: 'انخفاض في عدد الرحلات',
          descriptionAr: 'عدد الرحلات الحالي أقل من الشهر السابق بنسبة ${tripsChange.abs()}%.',
          severity: 'warning',
          suggestionAr: 'تحقق من أسباب تراجع الطلب واتخاذ إجراءات.',
        ));
      }
    }

    final topExpenseCategory = expensesByCategory.isNotEmpty
        ? expensesByCategory.reduce((a, b) {
            final aAmount = (a['amount'] as double?) ?? 0.0;
            final bAmount = (b['amount'] as double?) ?? 0.0;
            return aAmount >= bAmount ? a : b;
          })
        : null;
    if (topExpenseCategory != null && currentExpenses > 0) {
      final topAmount = (topExpenseCategory['amount'] as double?) ?? 0.0;
      final topPct = (topAmount / currentExpenses * 100).toInt();
      if (topPct > 50) {
        insights.add(InsightItem(
          titleAr: 'تركيز مصاريف مرتفع',
          descriptionAr: 'فئة "${topExpenseCategory['label'] ?? 'مصاريف'}" تمثل $topPct% من إجمالي المصاريف.',
          severity: 'warning',
          suggestionAr: 'ابحث عن طرق لتقليل هذه الفئة من المصاريف.',
        ));
      }
    }

    if (predictedNextProfit > 0 && averageMonthlyProfit > 0 && predictedNextProfit < averageMonthlyProfit * 0.5) {
      insights.add(InsightItem(
        titleAr: 'تنبيه: انخفاض متوقع في الأرباح',
        descriptionAr: 'الأرباح المتوقعة للشهر القادم أقل من المعدل الشهري بنسبة ${((1 - predictedNextProfit / averageMonthlyProfit) * 100).toInt()}%.',
        severity: 'alert',
        suggestionAr: 'راجع التكاليف وتأكد من جدولة الرحلات المربحة.',
      ));
    }

    if (revenueGrowthRate > 0.15) {
      insights.add(InsightItem(
        titleAr: 'نمو إيرادات قوي',
        descriptionAr: 'النمو في الإيرادات يُظهر اتجاهاً إيجابياً (%${(revenueGrowthRate * 100).toInt()}).',
        severity: 'success',
        suggestionAr: 'استثمر في توسيع الأسطول أو تحسين الخدمات.',
      ));
    }

    if (expenseGrowthRate > 0.2 && expenseGrowthRate > revenueGrowthRate) {
      insights.add(InsightItem(
        titleAr: 'مصاريف تنمو أسرع من الإيرادات',
        descriptionAr: 'نسبة نمو المصاريف (%${(expenseGrowthRate * 100).toInt()}) أعلى من نمو الإيرادات.',
        severity: 'warning',
        suggestionAr: 'قم بمراجعة العقود مع الموردين وورش الإصلاح.',
      ));
    }

    if (insights.isEmpty) {
      insights.add(const InsightItem(
        titleAr: 'الوضع الحالي مستقر',
        descriptionAr: 'لم يتم اكتشاف أنماط غير عادية في البيانات الحالية.',
        severity: 'info',
        suggestionAr: 'استمر في المراقبة الدورية لضمان الاستدامة.',
      ));
    }

    return insights;
  }

  static String computeOverallHealth({
    required double profit,
    required double revenue,
    required double expenses,
    required double predictedNextProfit,
    required double averageMonthlyProfit,
    required double outstandingInvoices,
    required double expenseGrowthRate,
  }) {
    final profitMargin = revenue > 0 ? profit / revenue : 0.0;
    final outstandingRatio = revenue > 0 ? outstandingInvoices / revenue : 0.0;

    int score = 0;
    if (profit > 0) {
      score += 2;
    }
    if (profitMargin > 0.15) {
      score += 2;
    } else if (profitMargin > 0.05) {
      score += 1;
    }
    if (predictedNextProfit >= averageMonthlyProfit * 0.8) {
      score += 2;
    }
    if (outstandingRatio < 0.2) {
      score += 2;
    } else if (outstandingRatio < 0.4) {
      score += 1;
    }
    if (expenseGrowthRate < 0.1) {
      score += 2;
    } else if (expenseGrowthRate < 0.2) {
      score += 1;
    }

    if (score >= 8) return 'ممتاز';
    if (score >= 6) return 'جيد';
    if (score >= 4) return 'مقبول';
    if (score >= 2) return 'يحتاج مراقبة';
    return 'حرج';
  }

  static List<Map<String, dynamic>> buildMonthlyTrends({
    required List<Map<String, dynamic>> trips,
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> treasuryTransactions,
    required List<Map<String, dynamic>> maintenances,
  }) {
    final now = DateTime.now();
    final months = <Map<String, dynamic>>[];

    for (int i = _historyMonths - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthStart = month.toIso8601String();
      final monthEnd = (month.month == 12
          ? DateTime(month.year + 1, 1, 1)
          : DateTime(month.year, month.month + 1, 1))
          .toIso8601String();

      double revenue = 0.0;
      double expenses = 0.0;

      for (final trip in trips) {
        final depDate = trip['departure_date']?.toString() ?? '';
        if (depDate.isNotEmpty && depDate.compareTo(monthStart) >= 0 && depDate.compareTo(monthEnd) < 0) {
          final price = (trip['price'] as num?)?.toDouble() ?? 0.0;
          final tripExp = (trip['specific_expenses'] as num?)?.toDouble() ?? 0.0;
          revenue += (price - tripExp);
        }
      }

      for (final inv in invoices) {
        final issueDate = inv['issue_date']?.toString() ?? '';
        if (issueDate.isNotEmpty && issueDate.compareTo(monthStart) >= 0 && issueDate.compareTo(monthEnd) < 0) {
          final amount = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
          final currency = (inv['currency']?.toString() ?? 'MAD');
          if (currency == 'EUR' || amount > 0) {
            revenue += amount;
          }
        }
      }

      for (final tx in treasuryTransactions) {
        final createdAt = tx['created_at']?.toString() ?? '';
        if (createdAt.isNotEmpty && createdAt.compareTo(monthStart) >= 0 && createdAt.compareTo(monthEnd) < 0) {
          final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
          final type = tx['type']?.toString() ?? '';
          if (type == 'trip_expense' || type == 'office_expense' || type == 'salary') {
            expenses += amount;
          }
        }
      }

      for (final maint in maintenances) {
        final maintDate = maint['maintenance_date']?.toString() ?? '';
        if (maintDate.isNotEmpty && maintDate.compareTo(monthStart) >= 0 && maintDate.compareTo(monthEnd) < 0) {
          expenses += (maint['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      months.add({
        'month': DateFormat('MMM yyyy').format(month),
        'revenue': revenue,
        'expenses': expenses,
        'profit': revenue - expenses,
      });
    }

    return months;
  }

  static List<Map<String, dynamic>> buildExpensesByCategory({
    required List<Map<String, dynamic>> maintenances,
    required List<Map<String, dynamic>> treasuryTransactions,
  }) {
    double maintenance = 0.0;
    double fuel = 0.0;
    double salary = 0.0;
    double office = 0.0;
    double other = 0.0;

    for (final m in maintenances) {
      maintenance += (m['amount'] as num?)?.toDouble() ?? 0.0;
    }

    for (final tx in treasuryTransactions) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      switch (tx['type']?.toString()) {
        case 'trip_expense':
          fuel += amount;
          break;
        case 'salary':
          salary += amount;
          break;
        case 'office_expense':
          office += amount;
          break;
        default:
          other += amount;
          break;
      }
    }

    return [
      {'category': 'maintenance', 'label': 'صيانة', 'amount': maintenance},
      {'category': 'fuel', 'label': 'وقود', 'amount': fuel},
      {'category': 'salary', 'label': 'رواتب', 'amount': salary},
      {'category': 'office', 'label': 'مصروفات مكتبية', 'amount': office},
      {'category': 'other', 'label': 'أخرى', 'amount': other},
    ];
  }

  static SeasonalityResult analyzeSeasonality(List<Map<String, dynamic>> monthlyData) {
    if (monthlyData.isEmpty) {
      return SeasonalityResult(
        bestMonth: const {'month': 'غير متاح', 'profit': 0.0},
        worstMonth: const {'month': 'غير متاح', 'profit': 0.0},
        trend: 'غير مؤكد',
        forecast: const [],
      );
    }

    final best = monthlyData.reduce((a, b) {
      final aProfit = (a['profit'] as double?) ?? 0.0;
      final bProfit = (b['profit'] as double?) ?? 0.0;
      return aProfit >= bProfit ? a : b;
    });

    final worst = monthlyData.reduce((a, b) {
      final aProfit = (a['profit'] as double?) ?? 0.0;
      final bProfit = (b['profit'] as double?) ?? 0.0;
      return aProfit <= bProfit ? a : b;
    });

    final trend = _calculateTrend(monthlyData);
    final forecast = _generateForecast(monthlyData, months: 3);

    return SeasonalityResult(
      bestMonth: best,
      worstMonth: worst,
      trend: trend,
      forecast: forecast,
    );
  }

  static String _calculateTrend(List<Map<String, dynamic>> monthlyData) {
    if (monthlyData.length < 2) return 'مستقر';

    final recent = monthlyData.length >= 3 ? monthlyData.sublist(monthlyData.length - 3) : monthlyData;
    final firstProfit = (recent.first['profit'] as double?) ?? 0.0;
    final lastProfit = (recent.last['profit'] as double?) ?? 0.0;

    if (firstProfit == 0 && lastProfit == 0) return 'مستقر';
    if (firstProfit == 0) return lastProfit > 0 ? 'تصاعدي' : 'تنازلي';

    final change = (lastProfit - firstProfit) / firstProfit.abs();
    if (change > 0.1) return 'تصاعدي';
    if (change < -0.1) return 'تنازلي';
    return 'مستقر';
  }

  static List<Map<String, dynamic>> _generateForecast(List<Map<String, dynamic>> monthlyData, {int months = 3}) {
    if (monthlyData.isEmpty) return const [];

    final profits = monthlyData.map((m) => (m['profit'] as double?) ?? 0.0).toList();
    final recentCount = profits.length >= 3 ? 3 : profits.length;
    final recent = profits.sublist(profits.length - recentCount);
    final recentAvg = recent.fold<double>(0.0, (a, b) => a + b) / recentCount;

    final firstRecent = recent.first;
    final lastRecent = recent.last;
    final trendSlope = firstRecent != 0 ? (lastRecent - firstRecent) / firstRecent.abs() / recentCount : 0.0;

    return List.generate(months, (index) {
      final forecastProfit = recentAvg * (1 + trendSlope * (index + 1));
      return {
        'month': 'التوقع +${index + 1}',
        'profit': forecastProfit < 0 ? 0.0 : forecastProfit,
        'isPrediction': true,
        'confidence': (0.9 - index * 0.15).clamp(0.3, 0.9),
      };
    });
  }

  static List<String> generateRecommendations({
    required List<Map<String, dynamic>> monthlyData,
    required List<Map<String, dynamic>> expensesByCategory,
    required List<Map<String, dynamic>> invoices,
    required double outstandingInvoices,
    required double currentRevenue,
    required double currentExpenses,
  }) {
    final recommendations = <String>[];

    if (expensesByCategory.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(expensesByCategory)
        ..sort((a, b) => ((b['amount'] as double?) ?? 0.0).compareTo((a['amount'] as double?) ?? 0.0));
      final top = sorted.first;
      final topAmount = (top['amount'] as double?) ?? 0.0;
      final totalExpenses = expensesByCategory.fold<double>(0.0, (sum, e) => sum + ((e['amount'] as double?) ?? 0.0));
      if (totalExpenses > 0 && (topAmount / totalExpenses) > 0.4) {
        recommendations.add('فئة "${top['label'] ?? 'مصاريف'}" تمثل أكثر من 40% من المصاريف. فكر في تحسين الكفاءة في هذا المجال.');
      }
    }

    if (outstandingInvoices > 0 && currentRevenue > 0) {
      final ratio = outstandingInvoices / currentRevenue;
      if (ratio > 0.3) {
        recommendations.add('الفواتير المعلقة مرتفعة (${(ratio * 100).toInt()}% من الإيرادات). يرجى متابعة التحصيل.');
      }
    }

    if (monthlyData.length >= 2) {
      final prevProfit = (monthlyData[monthlyData.length - 2]['profit'] as double?) ?? 0.0;
      final lastProfit = (monthlyData.last['profit'] as double?) ?? 0.0;
      if (prevProfit > 0 && lastProfit < prevProfit * 0.7) {
        recommendations.add('انخفاض ملحوظ في الأرباح مقارنة بالشهر السابق. راجع جدولة الرحلات.');
      }
    }

    if (currentExpenses > currentRevenue && currentRevenue > 0) {
      recommendations.add('المصاريف الحالية تفوق الإيرادات. يرجى تقليل التكاليف أو زيادة الرحلات المربحة.');
    }

    if (invoices.isNotEmpty) {
      final clientTotals = <String, double>{};
      for (final inv in invoices) {
        final clientId = (inv['client_id']?.toString() ?? '').trim();
        final amount = (inv['total_amount'] as double?) ?? 0.0;
        if (clientId.isNotEmpty) {
          clientTotals[clientId] = (clientTotals[clientId] ?? 0.0) + amount;
        }
      }
      final topClients = clientTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      if (topClients.isNotEmpty) {
        recommendations.add('العميل "${topClients.first.key}" هو الأكبر من حيث قيمة الفواتير. فكر في تعزيز العلاقة.');
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add('الوضع الحالي مستقر. استمر في المراقبة الدورية لضمان الاستدامة.');
    }

    return recommendations;
  }
}
