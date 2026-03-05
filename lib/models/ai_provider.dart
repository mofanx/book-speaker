import 'dart:convert';

enum ProviderType { openai, azure, google, custom }

extension ProviderTypeExt on ProviderType {
  String get label {
    switch (this) {
      case ProviderType.openai:
        return 'OpenAI';
      case ProviderType.azure:
        return 'Azure';
      case ProviderType.google:
        return 'Google';
      case ProviderType.custom:
        return 'Custom';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case ProviderType.openai:
        return 'https://api.openai.com/v1';
      case ProviderType.azure:
        return '';
      case ProviderType.google:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case ProviderType.custom:
        return '';
    }
  }
}

class AiProvider {
  final String id;
  String name;
  ProviderType type;
  String apiKey;
  String baseUrl;

  AiProvider({
    required this.id,
    required this.name,
    required this.type,
    this.apiKey = '',
    String? baseUrl,
  }) : baseUrl = baseUrl ?? type.defaultBaseUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
      };

  factory AiProvider.fromJson(Map<String, dynamic> json) {
    final type = ProviderType.values[json['type'] as int];
    return AiProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? type.defaultBaseUrl,
    );
  }

  String encode() => jsonEncode(toJson());
  static AiProvider decode(String s) =>
      AiProvider.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
