import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ai_provider.dart';
import '../models/settings.dart';

class SettingsService {
  final themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.system);
  static const String defaultOcrPrompt =
      'You are an OCR assistant for children\'s English textbooks. '
      'Extract text accurately and format as dialogue.';

  static const String defaultTextOptPrompt =
      'You are a text formatting assistant for children\'s English textbooks. '
      'Clean up the input text and format it as a well-structured dialogue.\n'
      'Rules:\n'
      '1. Each speaker\'s line should be on its own line\n'
      '2. Use "Speaker: text" format if speakers are identifiable\n'
      '3. Fix obvious typos and OCR artifacts\n'
      '4. Keep the original meaning intact\n'
      '5. Output ONLY the cleaned text, no explanations';

  static const _boxName = 'settings';
  static const _providerBoxName = 'providers';
  Box? _box;
  Box<String>? _providerBox;

  Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
    _providerBox ??= await Hive.openBox<String>(_providerBoxName);
    themeNotifier.value = themeMode;
  }

  // =========== App Settings ===========

  AppLocale get appLocale {
    final idx = _box?.get('appLocale', defaultValue: 0) ?? 0;
    return AppLocale.values[idx.clamp(0, AppLocale.values.length - 1)];
  }

  set appLocale(AppLocale v) => _box?.put('appLocale', v.index);

  AppThemeMode get themeMode {
    final idx = _box?.get('themeMode', defaultValue: 0) ?? 0;
    return AppThemeMode.values[idx];
  }

  set themeMode(AppThemeMode v) {
    _box?.put('themeMode', v.index);
    themeNotifier.value = v;
  }

  // =========== Provider Management ===========

  List<AiProvider> getProviders() {
    final list = <AiProvider>[];
    for (final key in _providerBox?.keys ?? []) {
      final raw = _providerBox?.get(key);
      if (raw != null) {
        try {
          list.add(AiProvider.decode(raw));
        } catch (_) {}
      }
    }
    return list;
  }

  AiProvider? getProvider(String? id) {
    if (id == null || id.isEmpty) return null;
    final raw = _providerBox?.get(id);
    if (raw == null) return null;
    try {
      return AiProvider.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProvider(AiProvider p) async {
    await _providerBox?.put(p.id, p.encode());
  }

  Future<void> deleteProvider(String id) async {
    await _providerBox?.delete(id);
    // Clear references to deleted provider
    if (ttsProviderId == id) ttsProviderId = '';
    if (ocrProviderId == id) ocrProviderId = '';
    if (textOptProviderId == id) textOptProviderId = '';
  }

  // =========== TTS Settings ===========

  TtsMode get ttsMode {
    final idx = _box?.get('ttsMode', defaultValue: 0) ?? 0;
    return TtsMode.values[idx.clamp(0, TtsMode.values.length - 1)];
  }

  set ttsMode(TtsMode v) => _box?.put('ttsMode', v.index);

  // Provider for traditional / LLM TTS
  String get ttsProviderId => _box?.get('ttsProviderId', defaultValue: '') ?? '';
  set ttsProviderId(String v) => _box?.put('ttsProviderId', v);

  // Voice name (traditional: en-US-JennyNeural, LLM: alloy/nova/shimmer)
  String get ttsVoice => _box?.get('ttsVoice', defaultValue: '') ?? '';
  set ttsVoice(String v) => _box?.put('ttsVoice', v);

  // Model for LLM TTS (e.g. gpt-4o-mini-tts)
  String get ttsModel => _box?.get('ttsModel', defaultValue: '') ?? '';
  set ttsModel(String v) => _box?.put('ttsModel', v);

  // Speech rate (0.1 – 1.0 for system, mapped for cloud)
  double get speechRate =>
      (_box?.get('speechRate', defaultValue: 0.5) ?? 0.5).toDouble();
  set speechRate(double v) => _box?.put('speechRate', v);

  // Pitch (0.5 – 2.0)
  double get pitch =>
      (_box?.get('pitch', defaultValue: 1.0) ?? 1.0).toDouble();
  set pitch(double v) => _box?.put('pitch', v);

  // System TTS engine package name (e.g. com.google.android.tts)
  String get systemTtsEngine =>
      _box?.get('systemTtsEngine', defaultValue: '') ?? '';
  set systemTtsEngine(String v) => _box?.put('systemTtsEngine', v);

  // System TTS language tag (e.g. en-US, zh-CN)
  String get systemTtsLanguage =>
      _box?.get('systemTtsLanguage', defaultValue: '') ?? '';
  set systemTtsLanguage(String v) => _box?.put('systemTtsLanguage', v);

  // =========== OCR Settings ===========

  OcrMode get ocrMode {
    final idx = _box?.get('ocrMode', defaultValue: 0) ?? 0;
    return OcrMode.values[idx.clamp(0, OcrMode.values.length - 1)];
  }

  set ocrMode(OcrMode v) => _box?.put('ocrMode', v.index);

  String get ocrProviderId => _box?.get('ocrProviderId', defaultValue: '') ?? '';
  set ocrProviderId(String v) => _box?.put('ocrProviderId', v);

  String get ocrModel => _box?.get('ocrModel', defaultValue: '') ?? '';
  set ocrModel(String v) => _box?.put('ocrModel', v);

  // =========== OCR Custom Prompt ===========

  String get ocrPrompt => _box?.get('ocrPrompt', defaultValue: '') ?? '';
  set ocrPrompt(String v) => _box?.put('ocrPrompt', v);
  String get effectiveOcrPrompt =>
      ocrPrompt.isNotEmpty ? ocrPrompt : defaultOcrPrompt;

  // =========== Text Optimization ===========

  bool get enableTextOptimization =>
      _box?.get('enableTextOptimization', defaultValue: false) ?? false;
  set enableTextOptimization(bool v) => _box?.put('enableTextOptimization', v);

  String get textOptProviderId =>
      _box?.get('textOptProviderId', defaultValue: '') ?? '';
  set textOptProviderId(String v) => _box?.put('textOptProviderId', v);

  String get textOptModel => _box?.get('textOptModel', defaultValue: '') ?? '';
  set textOptModel(String v) => _box?.put('textOptModel', v);

  String get textOptPrompt => _box?.get('textOptPrompt', defaultValue: '') ?? '';
  set textOptPrompt(String v) => _box?.put('textOptPrompt', v);
  String get effectiveTextOptPrompt =>
      textOptPrompt.isNotEmpty ? textOptPrompt : defaultTextOptPrompt;

  // =========== Translation Settings ===========

  String get translationProviderId =>
      _box?.get('translationProviderId', defaultValue: '') ?? '';
  set translationProviderId(String v) => _box?.put('translationProviderId', v);

  String get translationModel =>
      _box?.get('translationModel', defaultValue: '') ?? '';
  set translationModel(String v) => _box?.put('translationModel', v);

  String get translationTargetLang =>
      _box?.get('translationTargetLang', defaultValue: 'zh') ?? 'zh';
  set translationTargetLang(String v) => _box?.put('translationTargetLang', v);
}
