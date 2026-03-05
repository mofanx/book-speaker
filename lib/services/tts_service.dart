import 'dart:convert';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/settings.dart';
import 'settings_service.dart';

class TtsService {
  final SettingsService _settings;
  final FlutterTts _systemTts = FlutterTts();
  AudioPlayer? _audioPlayer;
  bool _isSpeaking = false;
  double _rate = 0.4;

  Function()? onComplete;
  Function()? onStart;

  TtsService(this._settings) {
    _rate = _settings.speechRate;
    _initSystemTts();
  }

  Future<void> _initSystemTts() async {
    await _systemTts.setLanguage('en-US');
    await _systemTts.setSpeechRate(_rate);
    await _systemTts.setVolume(1.0);
    await _systemTts.setPitch(1.0);

    _systemTts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });

    _systemTts.setStartHandler(() {
      _isSpeaking = true;
      onStart?.call();
    });
  }

  bool get isSpeaking => _isSpeaking;
  double get rate => _rate;

  Future<void> speak(String text) async {
    await stop();
    switch (_settings.ttsEngine) {
      case TtsEngine.system:
        await _systemTts.speak(text);
        break;
      case TtsEngine.azure:
        await _speakWithAzure(text);
        break;
      case TtsEngine.googleCloud:
        await _speakWithGoogleCloud(text);
        break;
    }
  }

  Future<void> _speakWithAzure(String text) async {
    _isSpeaking = true;
    onStart?.call();
    try {
      final region = _settings.ttsRegion;
      final apiKey = _settings.ttsApiKey;
      final voice = _settings.ttsVoice;
      final ssmlRate = '${((_rate * 2) * 100).round()}%';

      final ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">'
          '<voice name="$voice"><prosody rate="$ssmlRate">$text</prosody></voice></speak>';

      final response = await http.post(
        Uri.parse(
            'https://$region.tts.speech.microsoft.com/cognitiveservices/v1'),
        headers: {
          'Ocp-Apim-Subscription-Key': apiKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        },
        body: ssml,
      );

      if (response.statusCode == 200) {
        await _playAudioBytes(response.bodyBytes);
      } else {
        throw Exception('Azure TTS error: ${response.statusCode}');
      }
    } catch (e) {
      _isSpeaking = false;
      onComplete?.call();
    }
  }

  Future<void> _speakWithGoogleCloud(String text) async {
    _isSpeaking = true;
    onStart?.call();
    try {
      final apiKey = _settings.ttsApiKey;
      final voice = _settings.ttsVoice;
      final speedRate = (_rate * 2).clamp(0.25, 4.0);

      final body = jsonEncode({
        'input': {'text': text},
        'voice': {
          'languageCode': 'en-US',
          'name': voice.isEmpty ? 'en-US-Neural2-C' : voice,
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': speedRate,
        },
      });

      final response = await http.post(
        Uri.parse(
            'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioBytes = base64Decode(data['audioContent'] as String);
        await _playAudioBytes(audioBytes);
      } else {
        throw Exception('Google TTS error: ${response.statusCode}');
      }
    } catch (e) {
      _isSpeaking = false;
      onComplete?.call();
    }
  }

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

  Future<void> stop() async {
    _isSpeaking = false;
    await _systemTts.stop();
    await _audioPlayer?.stop();
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    _settings.speechRate = rate;
    await _systemTts.setSpeechRate(rate);
  }

  Future<void> dispose() async {
    await _systemTts.stop();
    _audioPlayer?.dispose();
  }
}
