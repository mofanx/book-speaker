import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_provider.dart';
import 'settings_service.dart';

class LlmService {
  final SettingsService _settings;

  LlmService(this._settings);

  // ---- Generic call with explicit provider/model ----

  Future<String> call({
    required AiProvider provider,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    if (provider.type == ProviderType.google) {
      return _callGemini(provider, model, messages);
    }
    return _callOpenAiCompatible(provider, model, messages);
  }

  Future<String> _callOpenAiCompatible(
    AiProvider provider,
    String model,
    List<Map<String, dynamic>> messages,
  ) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl.replaceAll(RegExp(r'/$'), '')
        : 'https://api.openai.com/v1';

    String url;
    Map<String, String> headers;

    if (provider.type == ProviderType.azure) {
      url =
          '$baseUrl/openai/deployments/$model/chat/completions?api-version=2024-02-01';
      headers = {
        'Content-Type': 'application/json',
        'api-key': provider.apiKey,
      };
    } else {
      url = '$baseUrl/chat/completions';
      headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${provider.apiKey}',
      };
    }

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': 0.3,
    });

    final response =
        await http.post(Uri.parse(url), headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception('LLM ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<String> _callGemini(
    AiProvider provider,
    String model,
    List<Map<String, dynamic>> messages,
  ) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl.replaceAll(RegExp(r'/$'), '')
        : 'https://generativelanguage.googleapis.com/v1beta';
    final url =
        '$baseUrl/models/$model:generateContent?key=${provider.apiKey}';

    final contents = messages.where((m) => m['role'] != 'system').map((m) {
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
            parts.add({
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': dataUrl.split(',').last,
              }
            });
          }
        }
        return {'role': role, 'parts': parts};
      }
    }).toList();

    final sysMsg =
        messages.where((m) => m['role'] == 'system').firstOrNull;

    final bodyMap = <String, dynamic>{
      'contents': contents,
      'generationConfig': {'temperature': 0.3},
    };
    if (sysMsg != null) {
      bodyMap['system_instruction'] = {
        'parts': [{'text': sysMsg['content']}]
      };
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );
    if (response.statusCode != 200) {
      throw Exception('Gemini ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  // ---- Convenience: text optimization ----

  Future<String> optimizeText(String rawText) async {
    final provider = _settings.getProvider(_settings.textOptProviderId);
    if (provider == null) throw Exception('No text optimization provider configured');
    final model = _settings.textOptModel;
    if (model.isEmpty) throw Exception('No text optimization model configured');

    return call(
      provider: provider,
      model: model,
      messages: [
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
      ],
    );
  }

  // ---- Convenience: OCR from image via LLM vision ----

  Future<String> ocrFromImage(File imageFile) async {
    final provider = _settings.getProvider(_settings.ocrProviderId);
    if (provider == null) throw Exception('No OCR provider configured');
    final model = _settings.ocrModel;
    if (model.isEmpty) throw Exception('No OCR model configured');

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    return call(
      provider: provider,
      model: model,
      messages: [
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
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
            },
          ],
        },
      ],
    );
  }

  // ---- Test connection ----

  Future<String?> testProvider(AiProvider provider, String model) async {
    try {
      final result = await call(
        provider: provider,
        model: model,
        messages: [
          {'role': 'user', 'content': 'Reply with only the word: OK'},
        ],
      );
      debugPrint('[LLM] test result: $result');
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }
}
