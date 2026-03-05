enum TtsEngine { system, azure, googleCloud }

enum OcrEngine { mlkit, llm }

enum LlmProvider { openai, azureOpenai, gemini, custom }

extension TtsEngineExt on TtsEngine {
  String get label {
    switch (this) {
      case TtsEngine.system:
        return 'System TTS';
      case TtsEngine.azure:
        return 'Azure TTS';
      case TtsEngine.googleCloud:
        return 'Google Cloud TTS';
    }
  }

  String get description {
    switch (this) {
      case TtsEngine.system:
        return 'Built-in Android TTS engine (offline)';
      case TtsEngine.azure:
        return 'Microsoft Azure Cognitive Services';
      case TtsEngine.googleCloud:
        return 'Google Cloud Text-to-Speech';
    }
  }
}

extension OcrEngineExt on OcrEngine {
  String get label {
    switch (this) {
      case OcrEngine.mlkit:
        return 'ML Kit (Offline)';
      case OcrEngine.llm:
        return 'LLM Vision';
    }
  }

  String get description {
    switch (this) {
      case OcrEngine.mlkit:
        return 'Google ML Kit - works offline';
      case OcrEngine.llm:
        return 'Use LLM to extract text from images';
    }
  }
}

extension LlmProviderExt on LlmProvider {
  String get label {
    switch (this) {
      case LlmProvider.openai:
        return 'OpenAI';
      case LlmProvider.azureOpenai:
        return 'Azure OpenAI';
      case LlmProvider.gemini:
        return 'Google Gemini';
      case LlmProvider.custom:
        return 'Custom (OpenAI-compatible)';
    }
  }

  bool get needsEndpoint {
    return this == LlmProvider.azureOpenai || this == LlmProvider.custom;
  }

  String get defaultModel {
    switch (this) {
      case LlmProvider.openai:
        return 'gpt-4o-mini';
      case LlmProvider.azureOpenai:
        return 'gpt-4o-mini';
      case LlmProvider.gemini:
        return 'gemini-2.0-flash';
      case LlmProvider.custom:
        return '';
    }
  }
}
