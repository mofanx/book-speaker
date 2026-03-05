import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/settings.dart';
import 'settings_service.dart';
import 'llm_service.dart';

class OcrService {
  final SettingsService _settings;
  final LlmService _llm;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  OcrService(this._settings, this._llm);

  Future<String> recognizeText(File imageFile) async {
    switch (_settings.ocrMode) {
      case OcrMode.mlkit:
        return _recognizeWithMlKit(imageFile);
      case OcrMode.llm:
        return _llm.ocrFromImage(imageFile);
    }
  }

  Future<String> _recognizeWithMlKit(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
