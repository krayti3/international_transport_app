import 'dart:io'; // ضروري لفحص المنصة
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MlTextRecognitionService {
  Future<String> recognizeText(String imagePath) async {
    // 🛡️ حماية نسخة الويندوز
    if (Platform.isWindows) {
      // نرجع وسم خاص تتوافق مع شاشة مسح التذاكر
      return "DESKTOP_MANUAL_MODE";
    }

    // 📱 كود الهاتف الأصلي (أندرويد وآيفون)
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return "خطأ أثناء قراءة النص: $e";
    } finally {
      textRecognizer.close();
    }
  }
}
