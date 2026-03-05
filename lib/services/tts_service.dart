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
  bool _systemReady = false;
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
    await _initSystemTts();
  }

  Future<void> _initSystemTts() async {
    try {
      _systemTts = FlutterTts();

      // CRITICAL: Do NOT use awaitSpeakCompletion(true)
      // It blocks forever on Xiaomi HyperOS / some Android 16 devices
      // because the completion callback never fires.
      await _systemTts!.awaitSpeakCompletion(false);

      // Log available engines
      try {
        final engines = await _systemTts!.getEngines;
        debugPrint('[TTS] available engines: $engines');
      } catch (e) {
        debugPrint('[TTS] getEngines failed: $e');
      }

      // Log available languages
      try {
        final languages = await _systemTts!.getLanguages;
        debugPrint('[TTS] available languages: $languages');
      } catch (e) {
        debugPrint('[TTS] getLanguages failed: $e');
      }

      await _systemTts!.setLanguage('en-US');
      await _systemTts!.setSpeechRate(_rate);
      await _systemTts!.setVolume(1.0);
      await _systemTts!.setPitch(1.0);

      _systemTts!.setStartHandler(() {
        debugPrint('[TTS] >> onStart callback');
        _isSpeaking = true;
        onStart?.call();
        // If a test is running, the start callback means TTS is working
        if (_testCompleter != null && !_testCompleter!.isCompleted) {
          _testCompleter!.complete(null); // success
        }
      });

      _systemTts!.setCompletionHandler(() {
        debugPrint('[TTS] >> onComplete callback');
        _isSpeaking = false;
        onComplete?.call();
      });

      _systemTts!.setErrorHandler((msg) {
        debugPrint('[TTS] >> onError callback: $msg');
        _isSpeaking = false;
        onComplete?.call();
        // If a test is running, report the error
        if (_testCompleter != null && !_testCompleter!.isCompleted) {
          _testCompleter!.complete('TTS error: $msg');
        }
      });

      _systemReady = true;
      debugPrint('[TTS] system TTS initialized, rate=$_rate');
    } catch (e) {
      debugPrint('[TTS] init failed: $e');
      _systemReady = false;
    }
  }

  bool get isSpeaking => _isSpeaking;
  double get rate => _rate;

  /// Speak text using the currently configured TTS mode.
  /// For system TTS this is fire-and-forget (returns immediately).
  /// For cloud/LLM TTS this awaits the HTTP call + audio playback start.
  Future<void> speak(String text) async {
    await stop();
    switch (_settings.ttsMode) {
      case TtsMode.system:
        _speakSystem(text); // fire-and-forget, do NOT await
        break;
      case TtsMode.traditional:
        await _speakTraditional(text);
        break;
      case TtsMode.llm:
        await _speakLlm(text);
        break;
    }
  }

  // ---- System TTS (fire-and-forget) ----

  void _speakSystem(String text) {
    if (!_systemReady || _systemTts == null) {
      debugPrint('[TTS] system not ready');
      onComplete?.call();
      return;
    }
    // Set speaking state immediately for responsive UI.
    // The setStartHandler callback will also fire when the engine actually begins.
    _isSpeaking = true;
    debugPrint('[TTS] calling speak("${text.length > 30 ? text.substring(0, 30) : text}...")');
    _systemTts!.speak(text).then((result) {
      debugPrint('[TTS] speak() returned: $result');
      // result == 1 means the utterance was queued successfully
      if (result != 1) {
        debugPrint('[TTS] speak() failed with result: $result');
        _isSpeaking = false;
        onComplete?.call();
        if (_testCompleter != null && !_testCompleter!.isCompleted) {
          _testCompleter!.complete('speak() returned $result — TTS engine may not be available');
        }
      }
    }).catchError((e) {
      debugPrint('[TTS] speak() threw: $e');
      _isSpeaking = false;
      onComplete?.call();
      if (_testCompleter != null && !_testCompleter!.isCompleted) {
        _testCompleter!.complete('speak() error: $e');
      }
    });
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

  /// Test TTS with a timeout. Returns null on success, error string on failure.
  /// Uses a Completer that resolves via the start/error callbacks,
  /// so it doesn't block on `speak()` completing.
  Future<String?> testSpeak({Duration timeout = const Duration(seconds: 8)}) async {
    _testCompleter = Completer<String?>();

    try {
      if (_settings.ttsMode == TtsMode.system) {
        // For system TTS: fire-and-forget speak, wait for callback
        if (!_systemReady || _systemTts == null) {
          await _initSystemTts();
        }
        if (!_systemReady) {
          return 'System TTS failed to initialize';
        }
        _speakSystem('Hello, this is a test.');
        // Wait for the start callback or error callback, with timeout
        final result = await _testCompleter!.future.timeout(
          timeout,
          onTimeout: () =>
              'Timeout: No response from TTS engine after ${timeout.inSeconds}s.\n'
              'Please check: Settings → System → Language → Text-to-Speech\n'
              'Make sure a TTS engine is installed and enabled.',
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
      }
      final engines = await _systemTts!.getEngines;
      return List<String>.from(engines ?? []);
    } catch (e) {
      debugPrint('[TTS] getEngines error: $e');
      return [];
    }
  }
}
