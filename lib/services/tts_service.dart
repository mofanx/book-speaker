import 'dart:convert';
import 'dart:io';
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

  TtsService(this._settings) {
    _rate = _settings.speechRate;
  }

  /// Must be awaited before first speak() call
  Future<void> init() async {
    await _initSystemTts();
  }

  Future<void> _initSystemTts() async {
    _systemTts = FlutterTts();

    // Await speak completion so callbacks fire reliably
    await _systemTts!.awaitSpeakCompletion(true);

    // Set engine (use default system engine)
    final engines = await _systemTts!.getEngines;
    debugPrint('[TTS] available engines: $engines');

    // Check and set language
    final langOk = await _systemTts!.isLanguageAvailable('en-US');
    debugPrint('[TTS] en-US available: $langOk');
    await _systemTts!.setLanguage('en-US');
    await _systemTts!.setSpeechRate(_rate);
    await _systemTts!.setVolume(1.0);
    await _systemTts!.setPitch(1.0);

    _systemTts!.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });

    _systemTts!.setStartHandler(() {
      _isSpeaking = true;
      onStart?.call();
    });

    _systemTts!.setErrorHandler((msg) {
      debugPrint('[TTS] error: $msg');
      _isSpeaking = false;
      onComplete?.call();
    });

    _systemReady = true;
    debugPrint('[TTS] system TTS initialized, rate=$_rate');
  }

  bool get isSpeaking => _isSpeaking;
  double get rate => _rate;

  Future<void> speak(String text) async {
    await stop();
    switch (_settings.ttsMode) {
      case TtsMode.system:
        await _speakSystem(text);
        break;
      case TtsMode.traditional:
        await _speakTraditional(text);
        break;
      case TtsMode.llm:
        await _speakLlm(text);
        break;
    }
  }

  // ---- System TTS ----

  Future<void> _speakSystem(String text) async {
    if (!_systemReady || _systemTts == null) {
      debugPrint('[TTS] system not ready, re-initializing...');
      await _initSystemTts();
    }
    final result = await _systemTts!.speak(text);
    debugPrint('[TTS] speak result: $result');
    if (result != 1) {
      debugPrint('[TTS] speak returned non-1, TTS may not be working');
      _isSpeaking = false;
      onComplete?.call();
    }
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
          // Treat custom/openai as OpenAI-compatible audio endpoint
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

  /// Quick test: speak a short sentence, return null on success or error string
  Future<String?> testSpeak() async {
    try {
      await speak('Hello, this is a test.');
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
