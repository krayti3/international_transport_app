import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:international_transport_app/models/invoice.dart';
import 'package:international_transport_app/services/settings_service.dart';
import 'package:international_transport_app/services/client_service.dart';

class PdfService {
  static PdfService? _instance;
  static PdfService get instance => _instance ??= PdfService._();
  PdfService._();

  static Future<Uint8List?> _fetchLogoBytes() async {
    try {
      final sysSettings = await SettingsService().getSystemSettings();
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

    final companyName = 'Ø´Ø±ÙƒØ© Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ';
    final reportDate = DateTime.now();
    final formattedDate = '${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}';
    final clientName = client['name']?.toString() ?? 'Ø¨Ø¯ÙˆÙ† Ø§Ø³Ù…';
    final clientPhone = client['phone']?.toString() ?? '';
    final clientCity = client['city']?.toString() ?? '';
    final currencySymbol = currency == 'EUR' ? 'â‚¬' : 'DH';

    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      children: [
        _cell('Ø§Ù„ØªØ§Ø±ÙŠØ®', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø¨ÙŠØ§Ù† / Ø§Ù„Ø±Ø­Ù„Ø©', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ù…Ø·Ù„ÙˆØ¨', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ù…Ø¯ÙÙˆØ¹', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø±ØµÙŠØ¯ Ø§Ù„Ù…ØªØ¨Ù‚ÙŠ', amiriBold, isHeader: true),
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
          _cell('Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø¹Ù…Ù„ÙŠØ§Øª', amiri, colSpan: 5, align: pw.TextAlign.center),
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
              pw.Text('ÙƒØ´Ù Ø­Ø³Ø§Ø¨ Ø²Ø¨ÙˆÙ†', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ®Ø±Ø§Ø¬: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Ø§Ù„Ø²Ø¨ÙˆÙ†: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('Ø§Ù„Ù‡Ø§ØªÙ: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('Ø§Ù„Ù…Ø¯ÙŠÙ†Ø©: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
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
              pw.Text('ØªÙ… Ø¥Ù†Ø´Ø§Ø¡ Ù‡Ø°Ø§ Ø§Ù„ÙƒØ´Ù Ø¢Ù„ÙŠØ§Ù‹ Ø¨ÙˆØ§Ø³Ø·Ø© Ù†Ø¸Ø§Ù… Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ', style: pw.TextStyle(font: amiri, fontSize: 10, color: PdfColors.grey600)),
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
        textAlign: align ?? (text.contains('Ø¨Ø¯ÙˆÙ†') || text.contains('Ù„Ø§ ÙŠÙˆØ¬Ø¯') ? pw.TextAlign.center : pw.TextAlign.right),
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
      filename: 'ÙƒØ´Ù_Ø­Ø³Ø§Ø¨_${client['name'] ?? 'Ø²Ø¨ÙˆÙ†'}.pdf',
    );
  }


  Future<void> shareDashboardPdf({
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
    required double outstandingInvoices,
    required List<Map<String, dynamic>> monthlyRevenue,
    required List<Map<String, dynamic>> expensesByCategory,
    required List<Map<String, dynamic>> invoicesByStatus,
    required List<Map<String, dynamic>> tripsByMonth,
  }) async {
    final logoBytes = await _fetchLogoBytes();
    final pdfBytes = await _buildDashboardPdf(
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      outstandingInvoices: outstandingInvoices,
      monthlyRevenue: monthlyRevenue,
      expensesByCategory: expensesByCategory,
      invoicesByStatus: invoicesByStatus,
      tripsByMonth: tripsByMonth,
      logoBytes: logoBytes,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'dashboard_report.pdf',
    );
  }

  Future<Uint8List> _buildDashboardPdf({
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
    required double outstandingInvoices,
    required List<Map<String, dynamic>> monthlyRevenue,
    required List<Map<String, dynamic>> expensesByCategory,
    required List<Map<String, dynamic>> invoicesByStatus,
    required List<Map<String, dynamic>> tripsByMonth,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          ..._buildLogoSection(logoBytes),
          pw.Text('Dashboard Report', style: pw.TextStyle(font: amiriBold, fontSize: 20)),
          pw.SizedBox(height: 20),
          pw.Text('Total Revenue: ${totalRevenue.toStringAsFixed(2)} MAD', style: pw.TextStyle(font: amiri, fontSize: 14)),
          pw.Text('Total Expenses: ${totalExpenses.toStringAsFixed(2)} MAD', style: pw.TextStyle(font: amiri, fontSize: 14)),
          pw.Text('Net Profit: ${netProfit.toStringAsFixed(2)} MAD', style: pw.TextStyle(font: amiri, fontSize: 14)),
          pw.Text('Outstanding Invoices: ${outstandingInvoices.toStringAsFixed(2)} MAD', style: pw.TextStyle(font: amiri, fontSize: 14)),
        ],
      ),
    );

    return pdf.save();
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
    final companyName = 'Ø´Ø±ÙƒØ© Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ';
    final reportDate = DateTime.now();
    final formattedDate =
        '${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}';
    final clientName = client['name']?.toString() ?? 'Ø¨Ø¯ÙˆÙ† Ø§Ø³Ù…';
    final clientPhone = client['phone']?.toString() ?? '';
    final clientCity = client['city']?.toString() ?? '';
    final netTotal = totalRevenue - totalExpenses;
    final currencySymbol = currency == 'EUR' ? 'â‚¬' : 'DH';

    final summaryRows = <pw.TableRow>[];
    summaryRows.add(pw.TableRow(
      children: [
        _cell('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø¥ÙŠØ±Ø§Ø¯Ø§Øª', amiriBold, isHeader: true, align: pw.TextAlign.center),
        _cell('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…ØµØ§Ø±ÙŠÙ', amiriBold, isHeader: true, align: pw.TextAlign.center),
        _cell('Ø§Ù„ØµØ§ÙÙŠ', amiriBold, isHeader: true, align: pw.TextAlign.center),
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
        _cell('Ø§Ù„ØªØ§Ø±ÙŠØ®', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø§ØªØ¬Ø§Ù‡', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ù…Ø³Ø§Ø±', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø³Ø§Ø¦Ù‚', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø´Ø§Ø­Ù†Ø©', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø³Ø¹Ø±', amiriBold, isHeader: true),
        _cell('Ù…ØµØ§Ø±ÙŠÙ Ø§Ù„Ø±Ø­Ù„Ø©', amiriBold, isHeader: true),
      ],
    ));

    for (final trip in trips) {
      final date = trip['date_out']?.toString() ?? trip['departure_date']?.toString() ?? '';
      final direction = trip['direction']?.toString() ?? '';
      final directionLabel = direction == 'return' ? 'Ø¹ÙˆØ¯Ø©' : 'Ø°Ù‡Ø§Ø¨';
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
            child: pw.Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ø±Ø­Ù„Ø§Øª', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: amiri)),
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
              pw.Text('ØªÙ‚Ø±ÙŠØ± Ø±Ø­Ù„Ø§Øª Ø§Ù„Ø²Ø¨ÙˆÙ†', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ®Ø±Ø§Ø¬: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Ø§Ù„Ø²Ø¨ÙˆÙ†: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('Ø§Ù„Ù‡Ø§ØªÙ: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('Ø§Ù„Ù…Ø¯ÙŠÙ†Ø©: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Ø§Ù„Ù…Ù„Ø®Øµ Ø§Ù„Ù…Ø§Ù„ÙŠ', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
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
              pw.Text('ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ø±Ø­Ù„Ø§Øª', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
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
              pw.Text('ØªÙ… Ø¥Ù†Ø´Ø§Ø¡ Ù‡Ø°Ø§ Ø§Ù„ØªÙ‚Ø±ÙŠØ± Ø¢Ù„ÙŠØ§Ù‹ Ø¨ÙˆØ§Ø³Ø·Ø© Ù†Ø¸Ø§Ù… Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ',
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
      filename: 'ØªÙ‚Ø±ÙŠØ±_Ø±Ø­Ù„Ø§Øª_${client['name'] ?? 'Ø²Ø¨ÙˆÙ†'}.pdf',
    );
  }

  Future<Uint8List> buildInvoicePdf({
    required Invoice invoice,
    required List<Map<String, dynamic>> payments,
  }) async {
    final pdf = pw.Document();
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();
    final companyName = 'Ø´Ø±ÙƒØ© Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ';
    final reportDate = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(reportDate);

    final invoiceNumber = invoice.invoiceNumber;
    final issueDate = invoice.issueDate != null ? DateFormat('dd/MM/yyyy').format(invoice.issueDate!) : '';
    final dueDate = invoice.dueDate != null ? DateFormat('dd/MM/yyyy').format(invoice.dueDate!) : '';
    final totalAmount = invoice.totalAmount.toDouble();
    final paidAmount = invoice.paidAmount?.toDouble() ?? 0.0;
    final remaining = totalAmount - paidAmount;
    final status = invoice.status;
    final clientService = ClientService();
    final client = invoice.clientId.isNotEmpty
        ? await clientService.getClientById(invoice.clientId)
        : null;
    final clientName = client?.name ?? 'Unknown';
    final clientPhone = client?.phone ?? '';
    final clientCity = client?.city ?? '';
    final route = invoice.route ?? '';
    final currency = invoice.currency ?? 'MAD';
    final currencySymbol = currency == 'EUR' ? 'â‚¬' : 'DH';
    final bankInfoText = invoice.bankInfoText;
    final bankAccount = invoice.bankAccountId != null
        ? await clientService.getBankAccountById(invoice.bankAccountId!)
        : null;
    final bankName = bankAccount?.bankName ?? '';
    final accountNumber = bankAccount?.accountNumber ?? '';
    final logoBytes = await _fetchLogoBytes();

    String statusLabel = 'ØºÙŠØ± Ù…Ø¯ÙÙˆØ¹Ø©';
    switch (status) {
      case 'paid':
        statusLabel = 'Ù…Ø¯ÙÙˆØ¹Ø©';
        break;
      case 'partially_paid':
        statusLabel = 'Ù…Ø¯ÙÙˆØ¹Ø© Ø¬Ø²Ø¦ÙŠØ§Ù‹';
        break;
      default:
        statusLabel = 'ØºÙŠØ± Ù…Ø¯ÙÙˆØ¹Ø©';
    }

    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      children: [
        _cell('Ø§Ù„Ø¨ÙŠØ§Ù†', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ù…Ø¨Ù„Øº', amiriBold, isHeader: true),
      ],
    ));

    rows.add(pw.TableRow(
      children: [
        _cell('Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ', amiri),
        _cell('${totalAmount.toStringAsFixed(2)} $currencySymbol', amiri),
      ],
    ));
    rows.add(pw.TableRow(
      children: [
        _cell('Ø§Ù„Ù…Ø¯ÙÙˆØ¹', amiri),
        _cell('${paidAmount.toStringAsFixed(2)} $currencySymbol', amiri),
      ],
    ));
    rows.add(pw.TableRow(
      children: [
        _cell('Ø§Ù„Ù…ØªØ¨Ù‚ÙŠ', amiriBold),
        _cell('${remaining.toStringAsFixed(2)} $currencySymbol', amiriBold),
      ],
    ));

    if (payments.isNotEmpty) {
      rows.add(pw.TableRow(
        children: [
          _cell('ØªØ§Ø±ÛŒØ® Ø§Ù„Ø¯ÙØ¹', amiriBold, isHeader: true),
          _cell('Ø§Ù„Ù…Ø¨Ù„Øº', amiriBold, isHeader: true),
          _cell('Ø·Ø±ÙŠÙ‚Ø© Ø§Ù„Ø¯ÙØ¹', amiriBold, isHeader: true),
          _cell('Ø§Ù„Ù…Ø±Ø¬Ø¹', amiriBold, isHeader: true),
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
              pw.Text('ÙØ§ØªÙˆØ±Ø© Ø¶Ø±ÙŠØ¨ÙŠØ©', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ®Ø±Ø§Ø¬: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Ø§Ù„Ø²Ø¨ÙˆÙ†: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('Ø§Ù„Ù‡Ø§ØªÙ: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('Ø§Ù„Ù…Ø¯ÙŠÙ†Ø©: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
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
                      pw.Text('Ø±Ù‚Ù… Ø§Ù„ÙØ§ØªÙˆØ±Ø©: $invoiceNumber', style: pw.TextStyle(font: amiri)),
                      if (issueDate.isNotEmpty) pw.Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø¥ØµØ¯Ø§Ø±: $issueDate', style: pw.TextStyle(font: amiri)),
                      if (dueDate.isNotEmpty) pw.Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ­Ù‚Ø§Ù‚: $dueDate', style: pw.TextStyle(font: amiri)),
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
                  child: pw.Text('Ø§Ù„Ù…Ø³Ø§Ø±/Ø§Ù„Ø±Ø­Ù„Ø©: $route', style: pw.TextStyle(font: amiri, fontSize: 13)),
                ),
              ],
              if (bankInfoText != null && bankInfoText.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Ù…Ø¹Ù„ÙˆÙ…Ø§Øª Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¨Ù†ÙƒÙŠ: $bankInfoText', style: pw.TextStyle(font: amiri, fontSize: 13)),
                ),
              ],
              if (bankInfoText == null || bankInfoText.isEmpty) ...[
                if (bankName.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¨Ù†ÙƒÙŠ: $bankName ($currency)', style: pw.TextStyle(font: amiri, fontSize: 13)),
                  ),
                ],
                if (accountNumber.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('Ø±Ù‚Ù… Ø§Ù„Ø­Ø³Ø§Ø¨: $accountNumber', style: pw.TextStyle(font: amiri, fontSize: 12)),
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
              pw.Text('ØªÙ… Ø¥Ù†Ø´Ø§Ø¡ Ù‡Ø°Ù‡ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø¢Ù„ÙŠØ§Ù‹ Ø¨ÙˆØ§Ø³Ø·Ø© Ù†Ø¸Ø§Ù… Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ',
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
      filename: 'ÙØ§ØªÙˆØ±Ø©_$name.pdf',
    );
  }

  Future<Uint8List> buildOutstandingStatementPdf({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> invoices,
  }) async {
    final pdf = pw.Document();
    final amiri = await PdfGoogleFonts.amiriRegular();
    final amiriBold = await PdfGoogleFonts.amiriBold();
    final companyName = 'Ø´Ø±ÙƒØ© Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ';
    final reportDate = DateTime.now();
    final formattedDate =
        '${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}';

    final clientName = client['name']?.toString() ??
        client['company_name']?.toString() ??
        client['full_name']?.toString() ??
        'Ø¨Ø¯ÙˆÙ† Ø§Ø³Ù…';
    final clientPhone = client['phone']?.toString() ?? '';
    final clientCity = client['city']?.toString() ?? '';
    final clientCurrency = client['currency']?.toString() ?? 'MAD';
    final clientCurrencySymbol = clientCurrency == 'EUR' ? 'â‚¬' : 'DH';
    final logoBytes = await _fetchLogoBytes();

    double totalRemaining = 0.0;
    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      children: [
        _cell('Ø±Ù‚Ù… Ø§Ù„ÙØ§ØªÙˆØ±Ø©', amiriBold, isHeader: true),
        _cell('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø¥ØµØ¯Ø§Ø±', amiriBold, isHeader: true),
        _cell('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ­Ù‚Ø§Ù‚', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ù…Ø¯ÙÙˆØ¹', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ù…ØªØ¨Ù‚ÙŠ', amiriBold, isHeader: true),
      ],
    ));

    for (final invoice in invoices) {
      final invoiceNumber = invoice['invoice_number']?.toString() ?? '#${invoice['id'] ?? '?'}';
      final currency = invoice['currency']?.toString() ?? clientCurrency;
      final currencySymbol = currency == 'EUR' ? 'â‚¬' : 'DH';
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
              pw.Text('ÙƒØ´Ù Ø§Ù„ÙÙˆØ§ØªÙŠØ± Ø§Ù„Ù…Ø³ØªØ­Ù‚Ø©', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ®Ø±Ø§Ø¬: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Ø§Ù„Ø²Ø¨ÙˆÙ†: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('Ø§Ù„Ù‡Ø§ØªÙ: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('Ø§Ù„Ù…Ø¯ÙŠÙ†Ø©: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
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
                  'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø³ØªØ­Ù‚: ${totalRemaining.toStringAsFixed(2)} $clientCurrencySymbol',
                  style: pw.TextStyle(font: amiriBold, fontSize: 14, color: PdfColors.red),
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Ø¥Ù„ÙŠÙƒÙ… Ø¨ÙŠØ§Ù† Ø¨Ø§Ù„ÙÙˆØ§ØªÙŠØ± Ø§Ù„Ù…Ø³ØªØ¬Ø¯Ø© ÙˆØ§Ù„Ù…Ø³ØªØ­Ù‚Ø© Ù„Ù„Ø¯ÙØ¹ ÙÙ‚Ø·. Ù†Ø£Ù…Ù„ ØªØ³ÙˆÙŠØªÙ‡Ø§ ÙÙŠ Ø£Ù‚Ø±Ø¨ ÙˆÙ‚Øª Ù…Ù…ÙƒÙ†. Ø´ÙƒØ±Ø§Ù‹ Ù„ØªØ¹Ø§Ù…Ù„ÙƒÙ… Ù…Ø¹ $companyName',
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
    final name = client['name']?.toString() ?? client['company_name']?.toString() ?? 'Ø²Ø¨ÙˆÙ†';
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'ÙƒØ´Ù_Ø§Ù„Ù…Ø³ØªØ­Ù‚Ø§Øª_$name.pdf',
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
    final companyName = 'Ø´Ø±ÙƒØ© Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ';
    final reportDate = DateTime.now();
    final formattedDate =
        '${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}';
    final clientName = client['name']?.toString() ?? 'Ø¨Ø¯ÙˆÙ† Ø§Ø³Ù…';
    final clientPhone = client['phone']?.toString() ?? '';
    final clientCity = client['city']?.toString() ?? '';
    final currencySymbol = currency == 'EUR' ? 'â‚¬' : 'DH';

    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(
      children: [
        _cell('Ø§Ù„ØªØ§Ø±ÙŠØ®', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø¨ÙŠØ§Ù†', amiriBold, isHeader: true),
        _cell('Ù…Ø¯ÙŠÙ†', amiriBold, isHeader: true),
        _cell('Ø¯Ø§Ø¦Ù†', amiriBold, isHeader: true),
        _cell('Ø§Ù„Ø±ØµÙŠØ¯', amiriBold, isHeader: true),
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
            child: pw.Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…Ø¹Ø§Ù…Ù„Ø§Øª', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: amiri)),
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
              pw.Text('ÙƒØ´Ù Ø­Ø³Ø§Ø¨ ØªÙØµÙŠÙ„ÙŠ', style: pw.TextStyle(font: amiriBold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ®Ø±Ø§Ø¬: $formattedDate', style: pw.TextStyle(font: amiri, fontSize: 12)),
              pw.Divider(height: 24, thickness: 1.5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Ø§Ù„Ø²Ø¨ÙˆÙ†: $clientName', style: pw.TextStyle(font: amiriBold, fontSize: 14)),
                    if (clientPhone.isNotEmpty) pw.Text('Ø§Ù„Ù‡Ø§ØªÙ: $clientPhone', style: pw.TextStyle(font: amiri, fontSize: 13)),
                    if (clientCity.isNotEmpty) pw.Text('Ø§Ù„Ù…Ø¯ÙŠÙ†Ø©: $clientCity', style: pw.TextStyle(font: amiri, fontSize: 13)),
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
                  'Ø§Ù„Ø±ØµÙŠØ¯ Ø§Ù„Ø­Ø§Ù„ÙŠ: ${currentBalance.toStringAsFixed(2)} $currencySymbol',
                  style: pw.TextStyle(font: amiriBold, fontSize: 14, color: PdfColors.blue),
                ),
              ),
              pw.Spacer(),
              pw.Text('ØªÙ… Ø¥Ù†Ø´Ø§Ø¡ Ù‡Ø°Ø§ Ø§Ù„ÙƒØ´Ù Ø¢Ù„ÙŠØ§Ù‹ Ø¨ÙˆØ§Ø³Ø·Ø© Ù†Ø¸Ø§Ù… Ø§Ù„Ù†Ù‚Ù„ Ø§Ù„Ø¯ÙˆÙ„ÙŠ',
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
    final name = client['name']?.toString() ?? client['company_name']?.toString() ?? 'Ø²Ø¨ÙˆÙ†';
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'ÙƒØ´Ù_Ø­Ø³Ø§Ø¨_$name.pdf',
    );
  }
}



