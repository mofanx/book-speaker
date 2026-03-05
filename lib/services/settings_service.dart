import 'package:hive_flutter/hive_flutter.dart';
import '../models/settings.dart';

class SettingsService {
  static const _boxName = 'settings';
  Box? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
  }

  // ---- TTS Settings ----

  TtsEngine get ttsEngine {
    final idx = _box?.get('ttsEngine', defaultValue: 0) ?? 0;
    return TtsEngine.values[idx.clamp(0, TtsEngine.values.length - 1)];
  }

  set ttsEngine(TtsEngine v) => _box?.put('ttsEngine', v.index);

  String get ttsApiKey =>
      _box?.get('ttsApiKey', defaultValue: '') ?? '';

  set ttsApiKey(String v) => _box?.put('ttsApiKey', v);

  String get ttsRegion =>
      _box?.get('ttsRegion', defaultValue: 'eastus') ?? 'eastus';

  set ttsRegion(String v) => _box?.put('ttsRegion', v);

  String get ttsVoice =>
      _box?.get('ttsVoice', defaultValue: 'en-US-JennyNeural') ??
      'en-US-JennyNeural';

  set ttsVoice(String v) => _box?.put('ttsVoice', v);

  double get speechRate =>
      (_box?.get('speechRate', defaultValue: 0.4) ?? 0.4).toDouble();

  set speechRate(double v) => _box?.put('speechRate', v);

  // ---- OCR Settings ----

  OcrEngine get ocrEngine {
    final idx = _box?.get('ocrEngine', defaultValue: 0) ?? 0;
    return OcrEngine.values[idx.clamp(0, OcrEngine.values.length - 1)];
  }

  set ocrEngine(OcrEngine v) => _box?.put('ocrEngine', v.index);

  // ---- LLM Settings ----

  bool get enableTextOptimization =>
      _box?.get('enableTextOptimization', defaultValue: false) ?? false;

  set enableTextOptimization(bool v) =>
      _box?.put('enableTextOptimization', v);

  LlmProvider get llmProvider {
    final idx = _box?.get('llmProvider', defaultValue: 0) ?? 0;
    return LlmProvider.values[idx.clamp(0, LlmProvider.values.length - 1)];
  }

  set llmProvider(LlmProvider v) => _box?.put('llmProvider', v.index);

  String get llmApiKey =>
      _box?.get('llmApiKey', defaultValue: '') ?? '';

  set llmApiKey(String v) => _box?.put('llmApiKey', v);

  String get llmEndpoint =>
      _box?.get('llmEndpoint', defaultValue: '') ?? '';

  set llmEndpoint(String v) => _box?.put('llmEndpoint', v);

  String get llmModel {
    final saved = _box?.get('llmModel', defaultValue: '') ?? '';
    return saved.isEmpty ? llmProvider.defaultModel : saved;
  }

  set llmModel(String v) => _box?.put('llmModel', v);
}
