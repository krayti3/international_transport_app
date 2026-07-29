import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MlTextRecognitionService {
  MlTextRecognitionService._();
  static final MlTextRecognitionService _instance = MlTextRecognitionService._();
  static MlTextRecognitionService get instance => _instance;

  TextRecognizer? _textRecognizer;

  Future<TextRecognizer> _getRecognizer() async {
    _textRecognizer ??= TextRecognizer();
    return _textRecognizer!;
  }

  Future<String> recognizeText(String imagePath) async {
    if (Platform.isWindows) {
      return "DESKTOP_MANUAL_MODE";
    }

    try {
      final recognizer = await _getRecognizer();
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return "خطأ أثناء قراءة النص: $e";
    }
  }

  Future<RecognizedText> processImage(String imagePath) async {
    if (Platform.isWindows) {
      return RecognizedText(text: '', blocks: const []);
    }

    try {
      final recognizer = await _getRecognizer();
      final inputImage = InputImage.fromFilePath(imagePath);
      return await recognizer.processImage(inputImage);
    } catch (e) {
      return RecognizedText(text: '', blocks: const []);
    }
  }

  Future<Map<String, String>> parseFuelReceipt(String imagePath) async {
    final recognizedText = await processImage(imagePath);

    String detectedStation = "";
    String detectedAmount = "";
    String detectedLiters = "";

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String text = line.text.toUpperCase();

        if (detectedStation.isEmpty &&
            (text.contains('AFRIQUIA') || text.contains('TOTAL') || text.contains('SHELL') || text.contains('REPSOL') || text.contains('PETROM'))) {
          detectedStation = line.text;
        }

        if (text.contains('L') || text.contains('LTR') || text.contains('LITERS')) {
          final match = RegExp(r'(\d+[.,]\d+)').firstMatch(text);
          if (match != null && detectedLiters.isEmpty) {
            detectedLiters = match.group(0)!.replaceAll(',', '.');
          }
        }

        if (text.contains('TOTAL') || text.contains('EUR') || text.contains(' NET ') || text.contains('TOTAL TTC')) {
          final match = RegExp(r'(\d+[.,]\d+)').firstMatch(text);
          if (match != null) {
            detectedAmount = match.group(0)!.replaceAll(',', '.');
          }
        }
      }
    }

    return {
      'station': detectedStation,
      'amount': detectedAmount,
      'liters': detectedLiters,
    };
  }

  Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
  }
}
