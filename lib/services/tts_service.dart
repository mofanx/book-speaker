import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/ai_provider.dart';
import '../models/settings.dart';
import 'settings_service.dart';

class TtsService {
  final SettingsService _settings;
  FlutterTts? _systemTts;
  AudioPlayer? _audioPlayer;
  bool _isSpeaking = false;
  bool _engineReady = false;
  bool _initialized = false;
  double _rate = 0.5;

  Function()? onComplete;
  Function()? onStart;

  // For test: signals when speech starts or completes
  Completer<String?>? _testCompleter;

  TtsService(this._settings) {
    _rate = _settings.speechRate;
  }

  /// Initialize system TTS engine. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    await _initSystemTts();
  }

  // ---- Initialization (following Kelivo's proven pattern) ----

  Future<void> _initSystemTts() async {
    try {
      _systemTts = FlutterTts();
      _bindHandlers();

      // Kick the engine: querying triggers native TTS binding
      await _kickEngine();
      // Poll until the engine is actually bound and responding
      await _ensureBound(timeout: const Duration(seconds: 5));
      // Pick the best engine (prefer Google TTS)
      await _selectEngine();
      // Apply speech config
      await _applyConfig();

      _initialized = true;
      debugPrint('[TTS] system TTS initialized, rate=$_rate, engineReady=$_engineReady');
    } catch (e) {
      debugPrint('[TTS] init failed: $e');
      _initialized = false;
    }
  }

  void _bindHandlers() {
    _systemTts!.setStartHandler(() {
      debugPrint('[TTS] >> onStart callback');
      _isSpeaking = true;
      onStart?.call();
      if (_testCompleter != null && !_testCompleter!.isCompleted) {
        _testCompleter!.complete(null); // success
      }
    });

    _systemTts!.setCompletionHandler(() {
      debugPrint('[TTS] >> onComplete callback');
      _isSpeaking = false;
      onComplete?.call();
    });

    _systemTts!.setCancelHandler(() {
      debugPrint('[TTS] >> onCancel callback');
      _isSpeaking = false;
      onComplete?.call();
    });

    _systemTts!.setErrorHandler((msg) {
      debugPrint('[TTS] >> onError callback: $msg');
      _isSpeaking = false;
      onComplete?.call();
      if (_testCompleter != null && !_testCompleter!.isCompleted) {
        _testCompleter!.complete('TTS error: $msg');
      }
    });
  }

  /// Querying languages/engines triggers the native TTS service to bind.
  Future<void> _kickEngine() async {
    try { await _systemTts!.getLanguages; } catch (_) {}
    try { await _systemTts!.getEngines; } catch (_) {}
  }

  /// Poll until getLanguages returns non-null, confirming the engine is bound.
  Future<void> _ensureBound({Duration timeout = const Duration(seconds: 3)}) async {
    if (_engineReady) return;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final langs = await _systemTts!.getLanguages;
        if (langs != null) {
          _engineReady = true;
          debugPrint('[TTS] engine bound successfully');
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 120));
    }
    debugPrint('[TTS] WARNING: engine not bound after ${timeout.inSeconds}s');
  }

  /// Pick the best TTS engine. Prefer Google TTS if available.
  Future<void> _selectEngine() async {
    try {
      final engines = await _systemTts!.getEngines;
      if (engines is List && engines.isNotEmpty) {
        String? chosen;
        for (final e in engines) {
          final s = e.toString();
          if (s.toLowerCase().contains('google')) { chosen = s; break; }
        }
        chosen ??= engines.first.toString();
        debugPrint('[TTS] selecting engine: $chosen');
        try { await _systemTts!.setEngine(chosen); } catch (_) {}
      }
    } catch (_) {}
  }

  /// Apply speech rate, pitch, volume, language, queue mode.
  Future<void> _applyConfig() async {
    try { await _systemTts!.setSpeechRate(_rate); } catch (_) {}
    try { await _systemTts!.setPitch(1.0); } catch (_) {}
    try { await _systemTts!.setVolume(1.0); } catch (_) {}
    // Set language
    try {
      final ok = await _systemTts!.isLanguageAvailable('en-US');
      if (ok == true) {
        await _systemTts!.setLanguage('en-US');
      }
    } catch (_) {}
    // Use awaitSpeakCompletion + QUEUE_ADD mode (Kelivo pattern)
    // The patched native plugin handles reconnection, so this is safe
    try { await _systemTts!.awaitSpeakCompletion(true); } catch (_) {}
    try { await _systemTts!.setQueueMode(1); } catch (_) {}
  }

  /// Recreate the entire FlutterTts instance and rebind everything.
  Future<void> _recreateEngine() async {
    debugPrint('[TTS] recreating engine...');
    try { await _systemTts!.stop(); } catch (_) {}
    _engineReady = false;
    _systemTts = FlutterTts();
    _bindHandlers();
    await _kickEngine();
    await _ensureBound(timeout: const Duration(seconds: 2));
    await _selectEngine();
    await _applyConfig();
  }

  bool get isSpeaking => _isSpeaking;
  double get rate => _rate;

  /// Speak text using the currently configured TTS mode.
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

  // ---- System TTS with aggressive retry (Kelivo pattern) ----

  Future<void> _speakSystemWithRetry(String text) async {
    if (_systemTts == null) {
      debugPrint('[TTS] system not initialized');
      onComplete?.call();
      return;
    }
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

  /// Try to speak with retries + engine recreation (Kelivo's _trySpeak pattern).
  Future<bool> _trySpeak(String text) async {
    await _ensureBound();
    dynamic res;
    // First attempt
    try { res = await _systemTts!.speak(text, focus: true); } catch (_) {}
    if (_speakOk(res)) return true;

    // Retry with engine selection (5 attempts, 180ms apart)
    await _selectEngine();
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 180));
      try { res = await _systemTts!.speak(text, focus: true); } catch (_) {}
      if (_speakOk(res)) return true;
    }

    // Nuclear option: recreate engine entirely and retry (5 attempts, 200ms apart)
    await _recreateEngine();
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      try { res = await _systemTts!.speak(text, focus: true); } catch (_) {}
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
    final ssmlRate = '${((_rate * 2) * 100).round()}%';

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
    final speedRate = (_rate * 2).clamp(0.25, 4.0);

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
      'speed': (_rate * 2).clamp(0.25, 4.0),
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
    await _systemTts?.stop();
    await _audioPlayer?.stop();
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    _settings.speechRate = rate;
    await _systemTts?.setSpeechRate(rate);
  }

  Future<void> dispose() async {
    await _systemTts?.stop();
    _audioPlayer?.dispose();
  }

  /// Test TTS. Returns null on success, error string on failure.
  Future<String?> testSpeak({Duration timeout = const Duration(seconds: 15)}) async {
    _testCompleter = Completer<String?>();

    try {
      if (_settings.ttsMode == TtsMode.system) {
        if (_systemTts == null) {
          await _initSystemTts();
        }
        if (_systemTts == null) {
          return 'System TTS failed to initialize';
        }
        // Use _trySpeak which has aggressive retry + engine recreation
        final ok = await _trySpeak('Hello, this is a test.');
        if (!ok) {
          return 'TTS speak failed after all retries.\n'
              'Please check: Settings → System → Language → Text-to-Speech\n'
              'Make sure a TTS engine is installed and enabled.';
        }
        // Wait for the start callback with timeout
        final result = await _testCompleter!.future.timeout(
          timeout,
          onTimeout: () => null, // If speak returned ok, treat timeout as success
        );
        return result;
      } else {
        // For cloud/LLM TTS: just try speaking
        await speak('Hello, this is a test.');
        return null;
      }
    } catch (e) {
      return e.toString();
    } finally {
      _testCompleter = null;
    }
  }

  /// Open Android system TTS settings so user can configure the engine.
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

  /// Set a specific TTS engine (e.g. 'com.google.android.tts')
  Future<void> setEngine(String engineName) async {
    if (_systemTts == null) return;
    try {
      await _systemTts!.setEngine(engineName);
      await _applyConfig();
      debugPrint('[TTS] engine set to: $engineName');
    } catch (e) {
      debugPrint('[TTS] setEngine error: $e');
    }
  }

  /// Get available system TTS engines
  Future<List<String>> getEngines() async {
    try {
      if (_systemTts == null) {
        _systemTts = FlutterTts();
        await _kickEngine();
        await _ensureBound(timeout: const Duration(seconds: 3));
      }
      final engines = await _systemTts!.getEngines;
      if (engines is List) {
        return engines.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[TTS] getEngines error: $e');
      return [];
    }
  }
}
