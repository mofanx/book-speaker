import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

typedef ErrorHandler = void Function(dynamic message);
typedef ProgressHandler = void Function(
    String text, int start, int end, String word);

enum TextToSpeechPlatform { android, ios }

class SpeechRateValidRange {
  final double min;
  final double normal;
  final double max;
  final TextToSpeechPlatform platform;

  SpeechRateValidRange(this.min, this.normal, this.max, this.platform);
}

// Provides Platform specific TTS services (Android: TextToSpeech, IOS: AVSpeechSynthesizer)
class FlutterTts {
  static const MethodChannel _channel = MethodChannel('flutter_tts');

  VoidCallback? startHandler;
  VoidCallback? completionHandler;
  VoidCallback? pauseHandler;
  VoidCallback? continueHandler;
  VoidCallback? cancelHandler;
  ProgressHandler? progressHandler;
  ErrorHandler? errorHandler;

  FlutterTts() {
    _channel.setMethodCallHandler(platformCallHandler);
  }

  /// [Future] which sets speak's future to return on completion of the utterance
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async =>
      await _channel.invokeMethod('awaitSpeakCompletion', awaitCompletion);

  /// [Future] which sets synthesize to file's future to return on completion of the synthesize
  Future<dynamic> awaitSynthCompletion(bool awaitCompletion) async =>
      await _channel.invokeMethod('awaitSynthCompletion', awaitCompletion);

  /// [Future] which invokes the platform specific method for speaking
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (!kIsWeb && Platform.isAndroid) {
      return await _channel.invokeMethod('speak', <String, dynamic>{
        "text": text,
        "focus": focus,
      });
    } else {
      return await _channel.invokeMethod('speak', text);
    }
  }

  /// [Future] which invokes the platform specific method for pause
  Future<dynamic> pause() async => await _channel.invokeMethod('pause');

  /// [Future] which invokes the platform specific method for getMaxSpeechInputLength
  Future<int?> get getMaxSpeechInputLength async {
    return await _channel.invokeMethod<int?>('getMaxSpeechInputLength');
  }

  /// [Future] which invokes the platform specific method for synthesizeToFile
  Future<dynamic> synthesizeToFile(String text, String fileName,
          [bool isFullPath = false]) async =>
      _channel.invokeMethod('synthesizeToFile', <String, dynamic>{
        "text": text,
        "fileName": fileName,
        "isFullPath": isFullPath,
      });

  /// [Future] which invokes the platform specific method for setLanguage
  Future<dynamic> setLanguage(String language) async =>
      await _channel.invokeMethod('setLanguage', language);

  /// [Future] which invokes the platform specific method for setSpeechRate
  /// Allowed values are in the range from 0.0 (slowest) to 1.0 (fastest)
  Future<dynamic> setSpeechRate(double rate) async =>
      await _channel.invokeMethod('setSpeechRate', rate);

  /// [Future] which invokes the platform specific method for setVolume
  Future<dynamic> setVolume(double volume) async =>
      await _channel.invokeMethod('setVolume', volume);

  /// [Future] which invokes the platform specific method for shared instance
  Future<dynamic> setSharedInstance(bool sharedSession) async =>
      await _channel.invokeMethod('setSharedInstance', sharedSession);

  /// [Future] which invokes the platform specific method for setEngine
  Future<dynamic> setEngine(String engine) async {
    await _channel.invokeMethod('setEngine', engine);
  }

  /// [Future] which invokes the platform specific method for setPitch
  /// 1.0 is default and ranges from .5 to 2.0
  Future<dynamic> setPitch(double pitch) async =>
      await _channel.invokeMethod('setPitch', pitch);

  /// [Future] which invokes the platform specific method for setVoice
  Future<dynamic> setVoice(Map<String, String> voice) async =>
      await _channel.invokeMethod('setVoice', voice);

  /// [Future] which resets the platform voice to the default
  Future<dynamic> clearVoice() async =>
      await _channel.invokeMethod('clearVoice');

  /// [Future] which invokes the platform specific method for stop
  Future<dynamic> stop() async => await _channel.invokeMethod('stop');

  /// [Future] which invokes the platform specific method for getLanguages
  Future<dynamic> get getLanguages async {
    final languages = await _channel.invokeMethod('getLanguages');
    return languages;
  }

  /// [Future] which invokes the platform specific method for getEngines
  /// Returns a list of installed TTS engines
  Future<dynamic> get getEngines async {
    final engines = await _channel.invokeMethod('getEngines');
    return engines;
  }

  /// [Future] which invokes the platform specific method for getDefaultEngine
  Future<dynamic> get getDefaultEngine async {
    final engineName = await _channel.invokeMethod('getDefaultEngine');
    return engineName;
  }

  /// [Future] which invokes the platform specific method for getDefaultVoice
  Future<dynamic> get getDefaultVoice async {
    final voice = await _channel.invokeMethod('getDefaultVoice');
    return voice;
  }

  /// [Future] which invokes the platform specific method for getVoices
  Future<dynamic> get getVoices async {
    final voices = await _channel.invokeMethod('getVoices');
    return voices;
  }

  /// [Future] which invokes the platform specific method for isLanguageAvailable
  Future<dynamic> isLanguageAvailable(String language) async =>
      await _channel.invokeMethod('isLanguageAvailable', language);

  /// [Future] which invokes the platform specific method for isLanguageInstalled
  Future<dynamic> isLanguageInstalled(String language) async =>
      await _channel.invokeMethod('isLanguageInstalled', language);

  /// [Future] which invokes the platform specific method for areLanguagesInstalled
  Future<dynamic> areLanguagesInstalled(List<String> languages) async =>
      await _channel.invokeMethod('areLanguagesInstalled', languages);

  Future<SpeechRateValidRange> get getSpeechRateValidRange async {
    final validRange = await _channel.invokeMethod('getSpeechRateValidRange')
        as Map<dynamic, dynamic>;
    final min = double.parse(validRange['min'].toString());
    final normal = double.parse(validRange['normal'].toString());
    final max = double.parse(validRange['max'].toString());
    final platformStr = validRange['platform'].toString();
    final platform =
        TextToSpeechPlatform.values.firstWhere((e) => e.name == platformStr);

    return SpeechRateValidRange(min, normal, max, platform);
  }

  /// [Future] which invokes the platform specific method for setSilence
  Future<dynamic> setSilence(int timems) async =>
      await _channel.invokeMethod('setSilence', timems);

  /// [Future] which invokes the platform specific method for setQueueMode
  Future<dynamic> setQueueMode(int queueMode) async =>
      await _channel.invokeMethod('setQueueMode', queueMode);

  void setStartHandler(VoidCallback callback) {
    startHandler = callback;
  }

  void setCompletionHandler(VoidCallback callback) {
    completionHandler = callback;
  }

  void setContinueHandler(VoidCallback callback) {
    continueHandler = callback;
  }

  void setPauseHandler(VoidCallback callback) {
    pauseHandler = callback;
  }

  void setCancelHandler(VoidCallback callback) {
    cancelHandler = callback;
  }

  void setProgressHandler(ProgressHandler callback) {
    progressHandler = callback;
  }

  void setErrorHandler(ErrorHandler handler) {
    errorHandler = handler;
  }

  /// Platform listeners
  Future<dynamic> platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case "speak.onStart":
        if (startHandler != null) {
          startHandler!();
        }
        break;

      case "synth.onStart":
        if (startHandler != null) {
          startHandler!();
        }
        break;
      case "speak.onComplete":
        if (completionHandler != null) {
          completionHandler!();
        }
        break;
      case "synth.onComplete":
        if (completionHandler != null) {
          completionHandler!();
        }
        break;
      case "speak.onPause":
        if (pauseHandler != null) {
          pauseHandler!();
        }
        break;
      case "speak.onContinue":
        if (continueHandler != null) {
          continueHandler!();
        }
        break;
      case "speak.onCancel":
        if (cancelHandler != null) {
          cancelHandler!();
        }
        break;
      case "speak.onError":
        if (errorHandler != null) {
          errorHandler!(call.arguments);
        }
        break;
      case 'speak.onProgress':
        if (progressHandler != null) {
          final args = call.arguments as Map<dynamic, dynamic>;
          progressHandler!(
            args['text'].toString(),
            int.parse(args['start'].toString()),
            int.parse(args['end'].toString()),
            args['word'].toString(),
          );
        }
        break;
      case "synth.onError":
        if (errorHandler != null) {
          errorHandler!(call.arguments);
        }
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  Future<void> setAudioAttributesForNavigation() async {
    await _channel.invokeMethod('setAudioAttributesForNavigation');
  }
}
