import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/ai_provider.dart';
import '../models/settings.dart';
import 'settings_service.dart';

/// Singleton TTS service. Uses ONE FlutterTts instance to avoid
/// static MethodChannel handler competition (flutter_tts uses a
/// static const MethodChannel — multiple FlutterTts instances
/// overwrite each other's callbacks).
class TtsService {
  // ---- Singleton ----
  static TtsService? _instance;
  static TtsService instance(SettingsService settings) {
    _instance ??= TtsService._(settings);
    return _instance!;
  }

  final SettingsService _settings;
  late FlutterTts _tts;
  AudioPlayer? _audioPlayer;
  bool _isSpeaking = false;
  bool _engineReady = false;
  bool _initialized = false;
  String? _error;

  Function()? onComplete;
  Function()? onStart;
  Completer<String?>? _testCompleter;

  TtsService._(this._settings);

  bool get isInitialized => _initialized;
  bool get isSpeaking => _isSpeaking;
  bool get engineReady => _engineReady;
  String? get error => _error;
  double get rate => _settings.speechRate;
  double get pitch => _settings.pitch;
  String get engineId => _settings.systemTtsEngine;
  String get languageTag => _settings.systemTtsLanguage;

  /// Initialize system TTS engine. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    await _initSystemTts();
  }

  // ---- Initialization (Kelivo's proven pattern) ----

  Future<void> _initSystemTts() async {
    try {
      _tts = FlutterTts();
      _bindHandlers();
      await _kickEngine();
      await _ensureBound(timeout: const Duration(seconds: 5));
      await _selectEngine();
      await _applyConfig();
      _initialized = true;
      _error = null;
      debugPrint('[TTS] initialized, engineReady=$_engineReady');
    } catch (e) {
      debugPrint('[TTS] init failed: $e');
      _error = e.toString();
      _initialized = false;
    }
  }

  void _bindHandlers() {
    _tts.setStartHandler(() {
      debugPrint('[TTS] >> onStart');
      _isSpeaking = true;
      onStart?.call();
      if (_testCompleter != null && !_testCompleter!.isCompleted) {
        _testCompleter!.complete(null);
      }
    });
    _tts.setCompletionHandler(() {
      debugPrint('[TTS] >> onComplete');
      _isSpeaking = false;
      onComplete?.call();
    });
    _tts.setCancelHandler(() {
      debugPrint('[TTS] >> onCancel');
      _isSpeaking = false;
      onComplete?.call();
    });
    _tts.setPauseHandler(() {
      debugPrint('[TTS] >> onPause');
    });
    _tts.setContinueHandler(() {
      debugPrint('[TTS] >> onContinue');
    });
    _tts.setErrorHandler((msg) {
      debugPrint('[TTS] >> onError: $msg');
      _isSpeaking = false;
      _error = msg;
      onComplete?.call();
      if (_testCompleter != null && !_testCompleter!.isCompleted) {
        _testCompleter!.complete('TTS error: $msg');
      }
    });
  }

  Future<void> _kickEngine() async {
    try { await _tts.getLanguages; } catch (_) {}
    try { await _tts.getEngines; } catch (_) {}
  }

  Future<void> _ensureBound({Duration timeout = const Duration(seconds: 3)}) async {
    if (_engineReady) return;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final langs = await _tts.getLanguages;
        if (langs != null) {
          _engineReady = true;
          debugPrint('[TTS] engine bound');
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 120));
    }
    debugPrint('[TTS] WARNING: engine not bound after ${timeout.inSeconds}s');
  }

  Future<void> _selectEngine() async {
    // If user has a saved engine preference, use it
    final saved = _settings.systemTtsEngine;
    if (saved.isNotEmpty) {
      try { await _tts.setEngine(saved); return; } catch (_) {}
    }
    // Otherwise prefer Google TTS
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.isNotEmpty) {
        String? chosen;
        for (final e in engines) {
          final s = e.toString();
          if (s.toLowerCase().contains('google')) { chosen = s; break; }
        }
        chosen ??= engines.first.toString();
        debugPrint('[TTS] selecting engine: $chosen');
        try { await _tts.setEngine(chosen); } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _applyConfig() async {
    try { await _tts.setSpeechRate(_settings.speechRate); } catch (_) {}
    try { await _tts.setPitch(_settings.pitch); } catch (_) {}
    try { await _tts.setVolume(1.0); } catch (_) {}
    // Language: use saved preference, or device locale, or fallback
    final loc = ui.PlatformDispatcher.instance.locale;
    final defaultTag = _localeToTag(loc);
    try {
      final saved = _settings.systemTtsLanguage;
      final tag = saved.isNotEmpty ? saved : defaultTag;
      final res = await _tts.isLanguageAvailable(tag);
      if (res == true) {
        await _tts.setLanguage(tag);
      } else {
        final zh = loc.languageCode.toLowerCase().startsWith('zh');
        final fb = zh ? 'zh-CN' : 'en-US';
        final ok = await _tts.isLanguageAvailable(fb);
        if (ok == true) await _tts.setLanguage(fb);
      }
    } catch (_) {}
    try { await _tts.awaitSpeakCompletion(true); } catch (_) {}
    try { await _tts.awaitSynthCompletion(true); } catch (_) {}
    try { await _tts.setQueueMode(1); } catch (_) {}
  }

  static String _localeToTag(ui.Locale l) {
    final lang = l.languageCode;
    final country = l.countryCode;
    if (country != null && country.isNotEmpty) return '$lang-$country';
    return lang;
  }

  Future<void> _recreateEngine() async {
    debugPrint('[TTS] recreating engine...');
    try { await _tts.stop(); } catch (_) {}
    _engineReady = false;
    _tts = FlutterTts();
    _bindHandlers();
    await _kickEngine();
    await _ensureBound(timeout: const Duration(seconds: 2));
    await _selectEngine();
    await _applyConfig();
  }

  // ---- Public API: engines / languages ----

  Future<List<String>> getEngines() async {
    await _ensureBound();
    try {
      final res = await _tts.getEngines;
      if (res is List) return res.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  Future<List<String>> getLanguages() async {
    await _ensureBound();
    try {
      final res = await _tts.getLanguages;
      if (res is List) return res.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  Future<void> setEngineId(String id) async {
    _settings.systemTtsEngine = id;
    try { await _tts.setEngine(id); } catch (_) {}
    await _applyConfig();
    debugPrint('[TTS] engine set to: $id');
  }

  Future<void> setLanguageTag(String tag) async {
    _settings.systemTtsLanguage = tag;
    try { await _tts.setLanguage(tag); } catch (_) {}
    debugPrint('[TTS] language set to: $tag');
  }

  Future<void> setRate(double rate) async {
    final r = rate.clamp(0.1, 1.0);
    _settings.speechRate = r;
    try { await _tts.setSpeechRate(r); } catch (_) {}
  }

  Future<void> setPitch(double p) async {
    final v = p.clamp(0.5, 2.0);
    _settings.pitch = v;
    try { await _tts.setPitch(v); } catch (_) {}
  }

  // ---- Speak ----

  Future<void> speak(String text) async {
    await stop();
    switch (_settings.ttsMode) {
      case TtsMode.system:
        await _speakSystemWithRetry(text);
        break;
      case TtsMode.traditional:
        await _speakTraditional(text);
        break;
      case TtsMode.llm:
        await _speakLlm(text);
        break;
    }
  }

  Future<void> _speakSystemWithRetry(String text) async {
    _isSpeaking = true;
    onStart?.call();
    final ok = await _trySpeak(text);
    if (!ok) {
      debugPrint('[TTS] all speak attempts failed');
      _isSpeaking = false;
      onComplete?.call();
      if (_testCompleter != null && !_testCompleter!.isCompleted) {
        _testCompleter!.complete('TTS speak failed after all retries');
      }
    }
  }

  Future<bool> _trySpeak(String text) async {
    await _ensureBound();
    dynamic res;
    try { res = await _tts.speak(text, focus: true); } catch (_) {}
    if (_speakOk(res)) return true;

    await _selectEngine();
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 180));
      try { res = await _tts.speak(text, focus: true); } catch (_) {}
      if (_speakOk(res)) return true;
    }

    await _recreateEngine();
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      try { res = await _tts.speak(text, focus: true); } catch (_) {}
      if (_speakOk(res)) return true;
    }
    return false;
  }

  bool _speakOk(dynamic res) {
    if (res == null) return false;
    if (res is int) return res == 1;
    if (res is bool) return res == true;
    final s = res.toString();
    return s == '1' || s.toLowerCase() == 'true' || s.toLowerCase() == 'success';
  }

  // ---- Traditional Cloud TTS (Azure / Google) ----

  Future<void> _speakTraditional(String text) async {
    final provider = _settings.getProvider(_settings.ttsProviderId);
    if (provider == null) {
      onComplete?.call();
      return;
    }
    _isSpeaking = true;
    onStart?.call();

    try {
      late List<int> audioBytes;
      switch (provider.type) {
        case ProviderType.azure:
          audioBytes = await _azureTts(provider, text);
          break;
        case ProviderType.google:
          audioBytes = await _googleTts(provider, text);
          break;
        default:
          audioBytes = await _openaiStyleTts(provider, text, isTraditional: true);
          break;
      }
      await _playAudioBytes(audioBytes);
    } catch (e) {
      debugPrint('[TTS] traditional error: $e');
      _isSpeaking = false;
      onComplete?.call();
    }
  }

  Future<List<int>> _azureTts(AiProvider provider, String text) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://eastus.tts.speech.microsoft.com';
    final voice = _settings.ttsVoice.isNotEmpty
        ? _settings.ttsVoice
        : 'en-US-JennyNeural';
    final ssmlRate = '${((rate * 2) * 100).round()}%';

    final ssml =
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">'
        '<voice name="$voice"><prosody rate="$ssmlRate">$text</prosody></voice></speak>';

    final response = await http.post(
      Uri.parse('$baseUrl/cognitiveservices/v1'),
      headers: {
        'Ocp-Apim-Subscription-Key': provider.apiKey,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
      },
      body: ssml,
    );
    if (response.statusCode != 200) {
      throw Exception('Azure TTS ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  Future<List<int>> _googleTts(AiProvider provider, String text) async {
    final voice = _settings.ttsVoice.isNotEmpty
        ? _settings.ttsVoice
        : 'en-US-Neural2-C';
    final speedRate = (rate * 2).clamp(0.25, 4.0);

    final body = jsonEncode({
      'input': {'text': text},
      'voice': {'languageCode': 'en-US', 'name': voice},
      'audioConfig': {'audioEncoding': 'MP3', 'speakingRate': speedRate},
    });

    final response = await http.post(
      Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=${provider.apiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Google TTS ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return base64Decode(data['audioContent'] as String);
  }

  // ---- LLM TTS (OpenAI-style /audio/speech) ----

  Future<void> _speakLlm(String text) async {
    final provider = _settings.getProvider(_settings.ttsProviderId);
    if (provider == null) {
      onComplete?.call();
      return;
    }
    _isSpeaking = true;
    onStart?.call();
    try {
      final audioBytes =
          await _openaiStyleTts(provider, text, isTraditional: false);
      await _playAudioBytes(audioBytes);
    } catch (e) {
      debugPrint('[TTS] LLM error: $e');
      _isSpeaking = false;
      onComplete?.call();
    }
  }

  Future<List<int>> _openaiStyleTts(
    AiProvider provider,
    String text, {
    required bool isTraditional,
  }) async {
    final baseUrl =
        provider.baseUrl.isNotEmpty ? provider.baseUrl : 'https://api.openai.com/v1';
    final model = _settings.ttsModel.isNotEmpty
        ? _settings.ttsModel
        : (isTraditional ? 'tts-1' : 'gpt-4o-mini-tts');
    final voice = _settings.ttsVoice.isNotEmpty ? _settings.ttsVoice : 'alloy';

    final body = jsonEncode({
      'model': model,
      'input': text,
      'voice': voice,
      'speed': (rate * 2).clamp(0.25, 4.0),
    });

    final response = await http.post(
      Uri.parse('$baseUrl/audio/speech'),
      headers: {
        'Authorization': 'Bearer ${provider.apiKey}',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('OpenAI TTS ${response.statusCode}: ${response.body}');
    }
    return response.bodyBytes;
  }

  // ---- Audio playback ----

  Future<void> _playAudioBytes(List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
    await file.writeAsBytes(bytes);

    _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerComplete.listen((_) {
      _isSpeaking = false;
      onComplete?.call();
    });
    await _audioPlayer!.play(DeviceFileSource(file.path));
  }

  // ---- Controls ----

  Future<void> stop() async {
    _isSpeaking = false;
    try { await _tts.stop(); } catch (_) {}
    await _audioPlayer?.stop();
  }

  Future<void> dispose() async {
    try { await _tts.stop(); } catch (_) {}
    _audioPlayer?.dispose();
  }

  /// Test system TTS. Returns null on success, error string on failure.
  Future<String?> testSystemSpeak(String text, {Duration timeout = const Duration(seconds: 15)}) async {
    _testCompleter = Completer<String?>();
    try {
      final ok = await _trySpeak(text);
      if (!ok) {
        return 'TTS speak failed after all retries.\n'
            'Please check system TTS settings.';
      }
      final result = await _testCompleter!.future.timeout(
        timeout,
        onTimeout: () => null,
      );
      return result;
    } catch (e) {
      return e.toString();
    } finally {
      _testCompleter = null;
    }
  }

  /// Test TTS with currently configured mode.
  Future<String?> testSpeak({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      if (_settings.ttsMode == TtsMode.system) {
        return await testSystemSpeak('Hello, this is a test.', timeout: timeout);
      } else {
        await speak('Hello, this is a test.');
        return null;
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// Open Android system TTS settings.
  static Future<bool> openSystemTtsSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      const intent = AndroidIntent(
        action: 'com.android.settings.TTS_SETTINGS',
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('[TTS] openSystemTtsSettings failed: $e');
      return false;
    }
  }
}
