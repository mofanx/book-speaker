import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/settings.dart';
import 'settings_service.dart';

class LlmService {
  final SettingsService _settings;

  LlmService(this._settings);

  // ---- API Configuration ----

  String get _apiUrl {
    switch (_settings.llmProvider) {
      case LlmProvider.openai:
        return 'https://api.openai.com/v1/chat/completions';
      case LlmProvider.azureOpenai:
        final ep = _settings.llmEndpoint.trimRight().replaceAll(RegExp(r'/$'), '');
        return '$ep/openai/deployments/${_settings.llmModel}/chat/completions?api-version=2024-02-01';
      case LlmProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta/models/${_settings.llmModel}:generateContent?key=${_settings.llmApiKey}';
      case LlmProvider.custom:
        final ep = _settings.llmEndpoint.trimRight().replaceAll(RegExp(r'/$'), '');
        return '$ep/v1/chat/completions';
    }
  }

  Map<String, String> get _headers {
    switch (_settings.llmProvider) {
      case LlmProvider.openai:
      case LlmProvider.custom:
        return {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_settings.llmApiKey}',
        };
      case LlmProvider.azureOpenai:
        return {
          'Content-Type': 'application/json',
          'api-key': _settings.llmApiKey,
        };
      case LlmProvider.gemini:
        return {'Content-Type': 'application/json'};
    }
  }

  // ---- Internal Call Methods ----

  Future<String> _callOpenAiCompatible(List<Map<String, dynamic>> messages) async {
    final body = jsonEncode({
      'model': _settings.llmModel,
      'messages': messages,
      'temperature': 0.3,
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('LLM API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<String> _callGemini(List<Map<String, dynamic>> messages) async {
    final contents = messages
        .where((m) => m['role'] != 'system')
        .map((m) {
      final role = m['role'] == 'assistant' ? 'model' : 'user';
      if (m['content'] is String) {
        return {
          'role': role,
          'parts': [{'text': m['content']}],
        };
      } else {
        final parts = <Map<String, dynamic>>[];
        for (final part in m['content'] as List) {
          if (part['type'] == 'text') {
            parts.add({'text': part['text']});
          } else if (part['type'] == 'image_url') {
            final dataUrl = part['image_url']['url'] as String;
            final base64Data = dataUrl.split(',').last;
            parts.add({
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Data,
              }
            });
          }
        }
        return {'role': role, 'parts': parts};
      }
    }).toList();

    // Prepend system instruction from system message if present
    final systemMsg = messages.where((m) => m['role'] == 'system').firstOrNull;
    final systemInstruction = systemMsg != null
        ? {'parts': [{'text': systemMsg['content']}]}
        : null;

    final bodyMap = <String, dynamic>{
      'contents': contents,
      'generationConfig': {'temperature': 0.3},
    };
    if (systemInstruction != null) {
      bodyMap['system_instruction'] = systemInstruction;
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: jsonEncode(bodyMap),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  Future<String> _call(List<Map<String, dynamic>> messages) async {
    if (_settings.llmProvider == LlmProvider.gemini) {
      return _callGemini(messages);
    }
    return _callOpenAiCompatible(messages);
  }

  // ---- Public Methods ----

  /// Optimize pasted text: clean up formatting, extract dialogue
  Future<String> optimizeText(String rawText) async {
    final messages = [
      {
        'role': 'system',
        'content':
            'You are a text formatting assistant for children\'s English textbooks. '
            'Clean up the input text and format it as a well-structured dialogue.\n'
            'Rules:\n'
            '1. Each speaker\'s line should be on its own line\n'
            '2. Use "Speaker: text" format if speakers are identifiable\n'
            '3. Fix obvious typos and OCR artifacts\n'
            '4. Keep the original meaning intact\n'
            '5. Output ONLY the cleaned text, no explanations',
      },
      {'role': 'user', 'content': rawText},
    ];
    return await _call(messages);
  }

  /// Extract text from an image using LLM vision
  Future<String> ocrFromImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Image';

    final messages = [
      {
        'role': 'system',
        'content':
            'You are an OCR assistant for children\'s English textbooks. '
            'Extract text accurately and format as dialogue.',
      },
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                'Extract all English text from this textbook image. '
                'Format as dialogue with "Speaker: text" if applicable. '
                'Output ONLY the extracted text.',
          },
          {
            'type': 'image_url',
            'image_url': {'url': dataUrl},
          },
        ],
      },
    ];
    return await _call(messages);
  }
}
