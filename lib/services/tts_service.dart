import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  double _rate = 0.4;
  bool _isSpeaking = false;

  Function()? onComplete;
  Function()? onStart;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_rate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });

    _tts.setStartHandler(() {
      _isSpeaking = true;
      onStart?.call();
    });
  }

  bool get isSpeaking => _isSpeaking;
  double get rate => _rate;

  Future<void> speak(String text) async {
    await stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    await _tts.setSpeechRate(rate);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
