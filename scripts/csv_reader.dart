import 'dart:convert';
import 'dart:io';

class CsvRow {
  final Map<String, String> values;
  final List<String> headers;

  CsvRow(this.headers, this.values);

  String? get(String header) => values[header];
  String getOrEmpty(String header) => values[header] ?? '';
  int? getInt(String header) => int.tryParse(values[header]?.trim() ?? '');
  double? getDouble(String header) {
    final raw = values[header]?.trim() ?? '';
    if (raw.isEmpty) return null;
    // French number format: 6.000,00 or 6000,00 or 6000.00
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }
  bool? getBool(String header) {
    final raw = values[header]?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    return raw == 'true' || raw == '1' || raw == 'oui' || raw == 'yes';
  }
  DateTime? getDate(String header) {
    final raw = values[header]?.trim() ?? '';
    if (raw.isEmpty) return null;
    // Try DD/MM/YYYY
    final parts = raw.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(raw);
  }
}

Future<List<CsvRow>> readCsv(String filePath, {String delimiter = ';'}) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('CSV file not found: $filePath');
  }

  final bytes = await file.readAsBytes();
  // Try Windows-1252/Latin1 encoding first for French files
  String content;
  try {
    content = latin1.decode(bytes);
  } catch (_) {
    content = utf8.decode(bytes);
  }

  final lines = content.split(RegExp(r'\r?\n'));
  if (lines.isEmpty) return [];

  final headers = lines.first.split(delimiter).map((h) => h.trim()).toList();
  final rows = <CsvRow>[];

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final values = line.split(delimiter);
    if (values.length != headers.length) {
      // Pad or truncate to match headers
      while (values.length < headers.length) {
        values.add('');
      }
      values.removeRange(headers.length, values.length);
    }

    final valueMap = <String, String>{};
    for (var j = 0; j < headers.length; j++) {
      valueMap[headers[j]] = values[j].trim();
    }

    rows.add(CsvRow(headers, valueMap));
  }

  return rows;
}

Future<List<CsvRow>> readCsvFromDirectory(String csvFileName, {String delimiter = ';'}) async {
  final scriptDir = Directory.current.path;
  final possiblePaths = [
    '$scriptDir/csv/$csvFileName',
    '$scriptDir/../csv/$csvFileName',
    '$scriptDir/csv/$csvFileName',
  ];

  for (final path in possiblePaths) {
    if (await File(path).exists()) {
      return readCsv(path, delimiter: delimiter);
    }
  }

  throw Exception('CSV file not found: $csvFileName (searched in csv/ folder)');
}
