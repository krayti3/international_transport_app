import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:international_transport_app/models/invoice.dart';
import 'package:international_transport_app/services/supabase_service.dart';

class PdfService {
  static PdfService? _instance;
  static PdfService get instance => _instance ??= PdfService._();
  PdfService._();

  static Future<Uint8List?> _fetchLogoBytes() async {
    try {
      final sysSettings = await SupabaseService().getSystemSettings();
      final logoUrl = sysSettings?['logo_url']?.toString();
      if (logoUrl == null || logoUrl.isEmpty) return null;
      final response = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return Uint8List.fromList(response.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  static List<pw.Widget> _buildLogoSection(Uint8List? logoBytes) {
    if (logoBytes == null) return [];
    return [
      pw.SizedBox(
        width: 70,
        height: 70,
        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(height: 8),
    ];
  }

  Future<Uint8List> _buildPdf({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> transactions,
    String currency = 'MAD',
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();

    final companyName = 'شركة النقل الدولي';
    final reportDate = DateTime.now();
    final formattedDate = '${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}';
    final clientName = client['name']?.toString() ?? 'بدون اسم';
    final clientPhone = client['phone']?.toString() ?? '';
    final clientCity = client['city']?.toString() ?? '';
    final currencySymbol = currency == 'EUR' ? '€' : 'DH';

    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      children: [
        _cell('التاريخ', amiriBold, isHeader: true),
        _cell('البيان / الرحلة', amiriBold, isHeader: true),
        _cell('المبلغ المطلوب', amiriBold, isHeader: true),
        _cell('المبلغ المدفوع', amiriBold, isHeader: true),
        _cell('الرصيد المتبقي', amiriBold, isHeader: true),
      ],
    ));

    double accumulatedBalance = 0.0;
    for (final tx in transactions) {
      final date = tx['date']?.toString() ?? tx['created_at']?.toString() ?? '';
      final description = tx['description']?.toString() ?? tx['route']?.toString() ?? '';
      final amountRequired = (tx['total_amount'] as num?)?.toDouble() ?? (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final amountPaid = (tx['paid_amount'] as num?)?.toDouble() ?? 0.0;
      accumulatedBalance += (amountRequired - amountPaid);

      rows.add(pw.TableRow(
        children: [
          _cell(date, amiri),
          _cell(description, amiri),
          _cell('${amountRequired.toStringAsFixed(2)} $currencySymbol', amiri),
          _cell('${amountPaid.toStringAsFixed(2)} $currencySymbol', amiri),
          _cell('${accumulatedBalance.toStringAsFixed(2)} $currencySymbol', amiri),
        ],
      ));
    }

    if (rows.length == 1) {
      rows.add(pw.TableRow(
        children: [
          _cell('لا يوجد عمليات', amiri, colSpan: 5, align: pw.TextAlign.center),
        ],
      ));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              ..._buildLogoSection(logoBytes),
              pw.Text(companyName, style: pw.TextStyle(font: amiriBold, fontSize: 22)),
              pw.SizedBox(height: 4),
              pw.Text('كشف حساب زبون', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('تاريخ الاستخراج: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('الزبون: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('الهاتف: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('المدينة: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey700),
                defaultColumnWidth: const pw.FlexColumnWidth(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.4),
                  2: pw.FlexColumnWidth(1.4),
                  3: pw.FlexColumnWidth(1.4),
                  4: pw.FlexColumnWidth(1.4),
                },
                children: rows,
              ),
              pw.Spacer(),
              pw.Text('تم إنشاء هذا الكشف آلياً بواسطة نظام النقل الدولي', style: pw.TextStyle(font: amiri, fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _cell(String text, pw.Font font, {bool isHeader = false, int colSpan = 1, pw.TextAlign? align}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: isHeader
          ? pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8F0FE))
          : null,
      child: pw.Text(
        text,
        textAlign: align ?? (text.contains('بدون') || text.contains('لا يوجد') ? pw.TextAlign.center : pw.TextAlign.right),
        style: pw.TextStyle(font: font, fontSize: 11, fontWeight: isHeader ? pw.FontWeight.bold : null),
      ),
    );
  }

  Future<void> previewAndPrint({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> transactions,
    String currency = 'MAD',
  }) async {
    final logoBytes = await _fetchLogoBytes();
    final pdfBytes = await _buildPdf(client: client, transactions: transactions, currency: currency, logoBytes: logoBytes);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  Future<void> sharePdf({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> transactions,
    String currency = 'MAD',
  }) async {
    final logoBytes = await _fetchLogoBytes();
    final pdfBytes = await _buildPdf(client: client, transactions: transactions, currency: currency, logoBytes: logoBytes);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'كشف_حساب_${client['name'] ?? 'زبون'}.pdf',
    );
  }

  Future<Uint8List> _buildClientReportPdf({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> trips,
    required double totalRevenue,
    required double totalExpenses,
    String currency = 'MAD',
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();
    final companyName = 'شركة النقل الدولي';
    final reportDate = DateTime.now();
    final formattedDate =
        '${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}';
    final clientName = client['name']?.toString() ?? 'بدون اسم';
    final clientPhone = client['phone']?.toString() ?? '';
    final clientCity = client['city']?.toString() ?? '';
    final netTotal = totalRevenue - totalExpenses;
    final currencySymbol = currency == 'EUR' ? '€' : 'DH';

    final summaryRows = <pw.TableRow>[];
    summaryRows.add(pw.TableRow(
      children: [
        _cell('إجمالي الإيرادات', amiriBold, isHeader: true, align: pw.TextAlign.center),
        _cell('إجمالي المصاريف', amiriBold, isHeader: true, align: pw.TextAlign.center),
        _cell('الصافي', amiriBold, isHeader: true, align: pw.TextAlign.center),
      ],
    ));
    summaryRows.add(pw.TableRow(
      children: [
        _cell('${totalRevenue.toStringAsFixed(2)} $currencySymbol', amiri, align: pw.TextAlign.center),
        _cell('${totalExpenses.toStringAsFixed(2)} $currencySymbol', amiri, align: pw.TextAlign.center),
        _cell('${netTotal.toStringAsFixed(2)} $currencySymbol', amiri, align: pw.TextAlign.center),
      ],
    ));

    final tripRows = <pw.TableRow>[];
    tripRows.add(pw.TableRow(
      children: [
        _cell('التاريخ', amiriBold, isHeader: true),
        _cell('الاتجاه', amiriBold, isHeader: true),
        _cell('المسار', amiriBold, isHeader: true),
        _cell('السائق', amiriBold, isHeader: true),
        _cell('الشاحنة', amiriBold, isHeader: true),
        _cell('السعر', amiriBold, isHeader: true),
        _cell('مصاريف الرحلة', amiriBold, isHeader: true),
      ],
    ));

    for (final trip in trips) {
      final date = trip['date_out']?.toString() ?? trip['departure_date']?.toString() ?? '';
      final direction = trip['direction']?.toString() ?? '';
      final directionLabel = direction == 'return' ? 'عودة' : 'ذهاب';
      final route = trip['route']?.toString() ?? '';
      final driverName = trip['driver_name']?.toString() ?? '';
      final truckPlate = trip['truck_plate']?.toString() ?? '';
      final price = (trip['price'] as num?)?.toDouble() ?? 0.0;
      final expenses = (trip['specific_expenses'] as num?)?.toDouble() ?? 0.0;

      tripRows.add(pw.TableRow(
        children: [
          _cell(date, amiri),
          _cell(directionLabel, amiri),
          _cell(route, amiri),
          _cell(driverName, amiri),
          _cell(truckPlate, amiri),
          _cell('${price.toStringAsFixed(2)} $currencySymbol', amiri),
          _cell('${expenses.toStringAsFixed(2)} $currencySymbol', amiri),
        ],
      ));
    }

    if (tripRows.length == 1) {
      tripRows.add(pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text('لا توجد رحلات', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: amiri)),
          ),
        ],
      ));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              ..._buildLogoSection(logoBytes),
              pw.Text(companyName, style: pw.TextStyle(font: amiriBold, fontSize: 22)),
              pw.SizedBox(height: 4),
              pw.Text('تقرير رحلات الزبون', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('تاريخ الاستخراج: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('الزبون: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('الهاتف: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('المدينة: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('الملخص المالي', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey700),
                defaultColumnWidth: const pw.FlexColumnWidth(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                },
                children: summaryRows,
              ),
              pw.SizedBox(height: 24),
              pw.Text('تفاصيل الرحلات', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey700),
                defaultColumnWidth: const pw.FlexColumnWidth(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(0.8),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1.2),
                  5: pw.FlexColumnWidth(1),
                  6: pw.FlexColumnWidth(1),
                },
                children: tripRows,
              ),
              pw.Spacer(),
              pw.Text('تم إنشاء هذا التقرير آلياً بواسطة نظام النقل الدولي',
                  style: pw.TextStyle(font: amiri, fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  Future<void> previewClientReport({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> trips,
    required double totalRevenue,
    required double totalExpenses,
    String currency = 'MAD',
  }) async {
    final logoBytes = await _fetchLogoBytes();
    final pdfBytes = await _buildClientReportPdf(
      client: client,
      trips: trips,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      currency: currency,
      logoBytes: logoBytes,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  Future<void> shareClientReport({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> trips,
    required double totalRevenue,
    required double totalExpenses,
    String currency = 'MAD',
  }) async {
    final logoBytes = await _fetchLogoBytes();
    final pdfBytes = await _buildClientReportPdf(
      client: client,
      trips: trips,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      currency: currency,
      logoBytes: logoBytes,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'تقرير_رحلات_${client['name'] ?? 'زبون'}.pdf',
    );
  }

  Future<Uint8List> buildInvoicePdf({
    required Invoice invoice,
    required List<Map<String, dynamic>> payments,
  }) async {
    final pdf = pw.Document();
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();
    final companyName = 'شركة النقل الدولي';
    final reportDate = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(reportDate);

    final invoiceNumber = invoice.invoiceNumber;
    final issueDate = invoice.issueDate != null ? DateFormat('dd/MM/yyyy').format(invoice.issueDate!) : '';
    final dueDate = invoice.dueDate != null ? DateFormat('dd/MM/yyyy').format(invoice.dueDate!) : '';
    final totalAmount = invoice.totalAmount.toDouble();
    final paidAmount = invoice.paidAmount?.toDouble() ?? 0.0;
    final remaining = totalAmount - paidAmount;
    final status = invoice.status;
    final supabaseService = SupabaseService();
    final client = invoice.clientId.isNotEmpty
        ? await supabaseService.getClientById(invoice.clientId)
        : null;
    final clientName = client?.name ?? 'Unknown';
    final clientPhone = client?.phone ?? '';
    final clientCity = client?.city ?? '';
    final route = invoice.route ?? '';
    final currency = invoice.currency ?? 'MAD';
    final currencySymbol = currency == 'EUR' ? '€' : 'DH';
    final bankInfoText = invoice.bankInfoText;
    final bankAccount = invoice.bankAccountId != null
        ? await supabaseService.getBankAccountById(invoice.bankAccountId!)
        : null;
    final bankName = bankAccount?.bankName ?? '';
    final accountNumber = bankAccount?.accountNumber ?? '';
    final logoBytes = await _fetchLogoBytes();

    String statusLabel = 'غير مدفوعة';
    switch (status) {
      case 'paid':
        statusLabel = 'مدفوعة';
        break;
      case 'partially_paid':
        statusLabel = 'مدفوعة جزئياً';
        break;
      default:
        statusLabel = 'غير مدفوعة';
    }

    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      children: [
        _cell('البيان', amiriBold, isHeader: true),
        _cell('المبلغ', amiriBold, isHeader: true),
      ],
    ));

    rows.add(pw.TableRow(
      children: [
        _cell('الإجمالي', amiri),
        _cell('${totalAmount.toStringAsFixed(2)} $currencySymbol', amiri),
      ],
    ));
    rows.add(pw.TableRow(
      children: [
        _cell('المدفوع', amiri),
        _cell('${paidAmount.toStringAsFixed(2)} $currencySymbol', amiri),
      ],
    ));
    rows.add(pw.TableRow(
      children: [
        _cell('المتبقي', amiriBold),
        _cell('${remaining.toStringAsFixed(2)} $currencySymbol', amiriBold),
      ],
    ));

    if (payments.isNotEmpty) {
      rows.add(pw.TableRow(
        children: [
          _cell('تاریخ الدفع', amiriBold, isHeader: true),
          _cell('المبلغ', amiriBold, isHeader: true),
          _cell('طريقة الدفع', amiriBold, isHeader: true),
          _cell('المرجع', amiriBold, isHeader: true),
        ],
      ));

      for (final pay in payments) {
        final date = pay['payment_date']?.toString() ?? '';
        final amount = (pay['amount_paid'] as num?)?.toDouble() ?? 0.0;
        final method = pay['payment_method']?.toString() ?? '';
        final ref = pay['receipt_reference']?.toString() ?? '';
        rows.add(pw.TableRow(
          children: [
            _cell(date, amiri),
            _cell('${amount.toStringAsFixed(2)} $currencySymbol', amiri),
            _cell(method, amiri),
            _cell(ref, amiri),
          ],
        ));
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              ..._buildLogoSection(logoBytes),
              pw.Text(companyName, style: pw.TextStyle(font: amiriBold, fontSize: 22)),
              pw.SizedBox(height: 4),
              pw.Text('فاتورة ضريبية', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('تاريخ الاستخراج: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('الزبون: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('الهاتف: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('المدينة: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('رقم الفاتورة: $invoiceNumber', style: pw.TextStyle(font: amiri)),
                      if (issueDate.isNotEmpty) pw.Text('تاريخ الإصدار: $issueDate', style: pw.TextStyle(font: amiri)),
                      if (dueDate.isNotEmpty) pw.Text('تاريخ الاستحقاق: $dueDate', style: pw.TextStyle(font: amiri)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: status == 'paid'
                          ? PdfColor.fromInt(0xFFE8F5E9)
                          : status == 'partially_paid'
                              ? PdfColor.fromInt(0xFFFFF3E0)
                              : PdfColor.fromInt(0xFFFFEBEE),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(statusLabel, style: pw.TextStyle(font: amiriBold, fontSize: 12)),
                  ),
                ],
              ),
              if (route.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('المسار/الرحلة: $route', style: pw.TextStyle(font: amiri, fontSize: 13)),
                ),
              ],
              if (bankInfoText != null && bankInfoText.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('معلومات الحساب البنكي: $bankInfoText', style: pw.TextStyle(font: amiri, fontSize: 13)),
                ),
              ],
              if (bankInfoText == null || bankInfoText.isEmpty) ...[
                if (bankName.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('الحساب البنكي: $bankName ($currency)', style: pw.TextStyle(font: amiri, fontSize: 13)),
                  ),
                ],
                if (accountNumber.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('رقم الحساب: $accountNumber', style: pw.TextStyle(font: amiri, fontSize: 12)),
                  ),
                ],
              ],
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey700),
                defaultColumnWidth: const pw.FlexColumnWidth(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                },
                children: rows,
              ),
              pw.SizedBox(height: 24),
              pw.Text('تم إنشاء هذه الفاتورة آلياً بواسطة نظام النقل الدولي',
                  style: pw.TextStyle(font: amiri, fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  Future<void> previewInvoice({
    required Invoice invoice,
    required List<Map<String, dynamic>> payments,
  }) async {
    final pdfBytes = await buildInvoicePdf(invoice: invoice, payments: payments);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  Future<void> shareInvoice({
    required Invoice invoice,
    required List<Map<String, dynamic>> payments,
  }) async {
    final pdfBytes = await buildInvoicePdf(invoice: invoice, payments: payments);
    final name = invoice.invoiceNumber;
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'فاتورة_$name.pdf',
    );
  }

  Future<Uint8List> buildOutstandingStatementPdf({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> invoices,
  }) async {
    final pdf = pw.Document();
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();
    final companyName = 'شركة النقل الدولي';
    final reportDate = DateTime.now();
    final formattedDate =
        '${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}';

    final clientName = client['name']?.toString() ??
        client['company_name']?.toString() ??
        client['full_name']?.toString() ??
        'بدون اسم';
    final clientPhone = client['phone']?.toString() ?? '';
    final clientCity = client['city']?.toString() ?? '';
    final clientCurrency = client['currency']?.toString() ?? 'MAD';
    final clientCurrencySymbol = clientCurrency == 'EUR' ? '€' : 'DH';
    final logoBytes = await _fetchLogoBytes();

    double totalRemaining = 0.0;
    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      children: [
        _cell('رقم الفاتورة', amiriBold, isHeader: true),
        _cell('تاريخ الإصدار', amiriBold, isHeader: true),
        _cell('تاريخ الاستحقاق', amiriBold, isHeader: true),
        _cell('الإجمالي', amiriBold, isHeader: true),
        _cell('المدفوع', amiriBold, isHeader: true),
        _cell('المتبقي', amiriBold, isHeader: true),
      ],
    ));

    for (final invoice in invoices) {
      final invoiceNumber = invoice['invoice_number']?.toString() ?? '#${invoice['id'] ?? '?'}';
      final currency = invoice['currency']?.toString() ?? clientCurrency;
      final currencySymbol = currency == 'EUR' ? '€' : 'DH';
      final issueDate = invoice['issue_date']?.toString() ?? '';
      final dueDate = invoice['due_date']?.toString() ?? '';
      final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
      final paidAmount = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final remaining = totalAmount - paidAmount;
      totalRemaining += remaining;

      rows.add(pw.TableRow(
        children: [
          _cell(invoiceNumber, amiri),
          _cell(issueDate, amiri),
          _cell(dueDate, amiri),
          _cell('${totalAmount.toStringAsFixed(2)} $currencySymbol', amiri),
          _cell('${paidAmount.toStringAsFixed(2)} $currencySymbol', amiri),
          _cell('${remaining.toStringAsFixed(2)} $currencySymbol', amiri),
        ],
      ));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              ..._buildLogoSection(logoBytes),
              pw.Text(companyName, style: pw.TextStyle(font: amiriBold, fontSize: 22)),
              pw.SizedBox(height: 4),
              pw.Text('كشف الفواتير المستحقة', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('تاريخ الاستخراج: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('الزبون: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('الهاتف: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('المدينة: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey700),
                defaultColumnWidth: const pw.FlexColumnWidth(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.6),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1.2),
                  5: pw.FlexColumnWidth(1.2),
                },
                children: rows,
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'إجمالي المستحق: ${totalRemaining.toStringAsFixed(2)} $clientCurrencySymbol',
                  style: pw.TextStyle(font: amiriBold, fontSize: 14, color: PdfColors.red),
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'إليكم بيان بالفواتير المستجدة والمستحقة للدفع فقط. نأمل تسويتها في أقرب وقت ممكن. شكراً لتعاملكم مع $companyName',
                style: pw.TextStyle(font: amiri, fontSize: 11, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  Future<void> previewOutstandingStatement({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> invoices,
  }) async {
    final pdfBytes = await buildOutstandingStatementPdf(client: client, invoices: invoices);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  Future<void> shareOutstandingStatement({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> invoices,
  }) async {
    final pdfBytes = await buildOutstandingStatementPdf(client: client, invoices: invoices);
    final name = client['name']?.toString() ?? client['company_name']?.toString() ?? 'زبون';
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'كشف_المستحقات_$name.pdf',
    );
  }

  Future<Uint8List> buildClientStatementPdf({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> statementItems,
    required double currentBalance,
    String currency = 'MAD',
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();
    final companyName = 'شركة النقل الدولي';
    final reportDate = DateTime.now();
    final formattedDate =
        '${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}';
    final clientName = client['name']?.toString() ?? 'بدون اسم';
    final clientPhone = client['phone']?.toString() ?? '';
    final clientCity = client['city']?.toString() ?? '';
    final currencySymbol = currency == 'EUR' ? '€' : 'DH';

    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      children: [
        _cell('التاريخ', amiriBold, isHeader: true),
        _cell('البيان', amiriBold, isHeader: true),
        _cell('مدين', amiriBold, isHeader: true),
        _cell('دائن', amiriBold, isHeader: true),
        _cell('الرصيد', amiriBold, isHeader: true),
      ],
    ));

    for (final item in statementItems) {
      final date = item['date']?.toString() ?? '';
      final desc = item['description']?.toString() ?? '';
      final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
      final isDebit = item['isDebit'] == true;
      final balance = (item['balance'] as num?)?.toDouble() ?? 0.0;

      rows.add(pw.TableRow(
        children: [
          _cell(date, amiri),
          _cell(desc, amiri),
          _cell(isDebit ? '${amount.toStringAsFixed(2)} $currencySymbol' : '', amiri, align: pw.TextAlign.center),
          _cell(!isDebit ? '${amount.toStringAsFixed(2)} $currencySymbol' : '', amiri, align: pw.TextAlign.center),
          _cell('${balance.toStringAsFixed(2)} $currencySymbol', amiri, align: pw.TextAlign.center),
        ],
      ));
    }

    if (rows.length == 1) {
      rows.add(pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text('لا توجد معاملات', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: amiri)),
          ),
        ],
      ));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              ..._buildLogoSection(logoBytes),
              pw.Text(companyName, style: pw.TextStyle(font: amiriBold, fontSize: 22)),
              pw.SizedBox(height: 4),
              pw.Text('كشف حساب تفصيلي', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('تاريخ الاستخراج: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('الزبون: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('الهاتف: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('المدينة: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey700),
                defaultColumnWidth: const pw.FlexColumnWidth(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.4),
                  2: pw.FlexColumnWidth(1.4),
                  3: pw.FlexColumnWidth(1.4),
                  4: pw.FlexColumnWidth(1.4),
                },
                children: rows,
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'الرصيد الحالي: ${currentBalance.toStringAsFixed(2)} $currencySymbol',
                  style: pw.TextStyle(font: amiriBold, fontSize: 14, color: PdfColors.blue),
                ),
              ),
              pw.Spacer(),
              pw.Text('تم إنشاء هذا الكشف آلياً بواسطة نظام النقل الدولي',
                  style: pw.TextStyle(font: amiri, fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  Future<void> previewClientStatement({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> statementItems,
    required double currentBalance,
    String currency = 'MAD',
  }) async {
    final logoBytes = await _fetchLogoBytes();
    final pdfBytes = await buildClientStatementPdf(
      client: client,
      statementItems: statementItems,
      currentBalance: currentBalance,
      currency: currency,
      logoBytes: logoBytes,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  Future<void> shareClientStatement({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> statementItems,
    required double currentBalance,
    String currency = 'MAD',
  }) async {
    final logoBytes = await _fetchLogoBytes();
    final pdfBytes = await buildClientStatementPdf(
      client: client,
      statementItems: statementItems,
      currentBalance: currentBalance,
      currency: currency,
      logoBytes: logoBytes,
    );
    final name = client['name']?.toString() ?? client['company_name']?.toString() ?? 'زبون';
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'كشف_حساب_$name.pdf',
    );
  }
}
