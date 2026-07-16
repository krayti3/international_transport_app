import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

class ExcelService {
  static ExcelService? _instance;
  static ExcelService get instance => _instance ??= ExcelService._();
  ExcelService._();

  static const Map<String, String> _treasuryTypeLabels = {
    'capital_injection': 'تزويد رأس مال',
    'owner_withdrawal': 'سحب شخصي',
    'office_expense': 'مصروف مكتب',
    'salary': 'دفع راتب',
    'trip_revenue': 'إيراد رحلة',
    'trip_expense': 'مصروف رحلة',
  };

  static const Map<String, String> _invoiceStatusLabels = {
    'paid': 'مدفوعة',
    'partially_paid': 'مدفوعة جزئياً',
    'unpaid': 'غير مدفوعة',
  };

  Future<Uint8List> exportTreasuryTransactions(List<Map<String, dynamic>> transactions) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }
    final sheet = excel['سجلات_الخزينة'];

    final headers = <String>['التاريخ', 'النوع', 'المبلغ (DH)', 'الوصف'];
    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByString('${_columnLabel(c)}1')).value = TextCellValue(headers[c]);
    }

    for (var i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final type = tx['type']?.toString() ?? '';
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final description = tx['description']?.toString() ?? '';
      final createdAt = tx['created_at']?.toString() ?? '';
      final typeLabel = _treasuryTypeLabels[type] ?? type;

      final row = i + 2;
      final rowStr = row.toString();
      sheet.cell(CellIndex.indexByString('${_columnLabel(0)}$rowStr')).value = TextCellValue(createdAt);
      sheet.cell(CellIndex.indexByString('${_columnLabel(1)}$rowStr')).value = TextCellValue(typeLabel);
      sheet.cell(CellIndex.indexByString('${_columnLabel(2)}$rowStr')).value = DoubleCellValue(amount);
      sheet.cell(CellIndex.indexByString('${_columnLabel(3)}$rowStr')).value = TextCellValue(description);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  Future<Uint8List> exportInvoices(List<Map<String, dynamic>> invoices) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }
    final sheet = excel['الفواتير'];

    final headers = <String>[
      'رقم الفاتورة',
      'الزبون',
      'تاريخ الإصدار',
      'تاريخ الاستحقاق',
      'الإجمالي (DH)',
      'المدفوع (DH)',
      'المتبقي (DH)',
      'الحالة',
    ];
    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByString('${_columnLabel(c)}1')).value = TextCellValue(headers[c]);
    }

    for (var i = 0; i < invoices.length; i++) {
      final inv = invoices[i];
      final invoiceNumber = inv['invoice_number']?.toString() ?? '#${inv['id'] ?? '?'}';
      final clientName = inv['clients']?['name']?.toString() ?? 'بدون اسم';
      final issueDate = inv['issue_date']?.toString() ?? '';
      final dueDate = inv['due_date']?.toString() ?? '';
      final totalAmount = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
      final paidAmount = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final remaining = totalAmount - paidAmount;
      final status = inv['status']?.toString() ?? 'unpaid';
      final statusLabel = _invoiceStatusLabels[status] ?? status;

      final row = i + 2;
      final rowStr = row.toString();
      sheet.cell(CellIndex.indexByString('${_columnLabel(0)}$rowStr')).value = TextCellValue(invoiceNumber);
      sheet.cell(CellIndex.indexByString('${_columnLabel(1)}$rowStr')).value = TextCellValue(clientName);
      sheet.cell(CellIndex.indexByString('${_columnLabel(2)}$rowStr')).value = TextCellValue(issueDate);
      sheet.cell(CellIndex.indexByString('${_columnLabel(3)}$rowStr')).value = TextCellValue(dueDate);
      sheet.cell(CellIndex.indexByString('${_columnLabel(4)}$rowStr')).value = DoubleCellValue(totalAmount);
      sheet.cell(CellIndex.indexByString('${_columnLabel(5)}$rowStr')).value = DoubleCellValue(paidAmount);
      sheet.cell(CellIndex.indexByString('${_columnLabel(6)}$rowStr')).value = DoubleCellValue(remaining);
      sheet.cell(CellIndex.indexByString('${_columnLabel(7)}$rowStr')).value = TextCellValue(statusLabel);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  Future<Uint8List> exportFinancialReport(Map<String, double> report) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }
    final sheet = excel['التقرير_المالي'];

    final headers = <String>['البند', 'القيمة (DH)'];
    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByString('${_columnLabel(c)}1')).value = TextCellValue(headers[c]);
    }

    int row = 2;
    report.forEach((key, value) {
      final rowStr = row.toString();
      sheet.cell(CellIndex.indexByString('${_columnLabel(0)}$rowStr')).value = TextCellValue(key);
      sheet.cell(CellIndex.indexByString('${_columnLabel(1)}$rowStr')).value = DoubleCellValue(value);
      row++;
    });

    return Uint8List.fromList(excel.encode()!);
  }

  Future<void> shareExcel(Uint8List bytes, String filename) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$filename.xlsx');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'ملف Excel: $filename.xlsx',
      ),
    );
  }

  static String _columnLabel(int index) {
    var label = '';
    var i = index;
    while (i >= 0) {
      label = String.fromCharCode('A'.codeUnitAt(0) + (i % 26)) + label;
      i = (i ~/ 26) - 1;
    }
    return label;
  }
}
