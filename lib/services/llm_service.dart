import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_provider.dart';
import 'settings_service.dart';

class LlmService {
  final SettingsService _settings;

  LlmService(this._settings);

  // ---- Fetch Models ----

  Future<List<String>> fetchModels(AiProvider provider) async {
    try {
      if (provider.type == ProviderType.google) {
        return await _fetchGeminiModels(provider);
      }
      return await _fetchOpenAiCompatibleModels(provider);
    } catch (e) {
      debugPrint('[LLM] fetch models error: $e');
      return [];
    }
  }

  Future<List<String>> _fetchOpenAiCompatibleModels(AiProvider provider) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl.replaceAll(RegExp(r'/$'), '')
        : 'https://api.openai.com/v1';

    String url;
    Map<String, String> headers;

    if (provider.type == ProviderType.azure) {
      // Azure doesn't have a standard models endpoint in the same way,
      // it depends on deployments. Returning empty list to let user type it manually.
      return [];
    } else {
      url = '$baseUrl/models';
      headers = {
        'Authorization': 'Bearer ${provider.apiKey}',
      };
    }

    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch models ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final models = data['data'] as List;
    return models.map((e) => e['id'] as String).toList();
  }

  Future<List<String>> _fetchGeminiModels(AiProvider provider) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl.replaceAll(RegExp(r'/$'), '')
        : 'https://generativelanguage.googleapis.com/v1beta';
    final url = '$baseUrl/models?key=${provider.apiKey}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Gemini models ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final models = data['models'] as List;
    // Format is "models/gemini-pro", strip the "models/" prefix
    return models.map((e) {
      final name = e['name'] as String;
      return name.replaceFirst('models/', '');
    }).toList();
  }

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
        {'role': 'system', 'content': _settings.effectiveTextOptPrompt},
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
          'content': _settings.effectiveOcrPrompt,
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
