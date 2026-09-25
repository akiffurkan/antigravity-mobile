import 'ai_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/nvidia_nim_provider.dart';
import 'providers/openai_provider.dart';

class AIProviderFactory {
  static AIProvider create({
    required AIProviderType type,
    required String apiKey,
    String? model,
  }) {
    switch (type) {
      case AIProviderType.openAI:
        return OpenAIProvider(
          apiKey: apiKey,
          model: model ?? 'gpt-4o-mini',
        );
      case AIProviderType.gemini:
        return GeminiProvider(
          apiKey: apiKey,
          model: model ?? 'gemini-2.0-flash',
        );
      case AIProviderType.nvidiaNim:
        return NvidiaNimProvider(
          apiKey: apiKey,
          model: model ?? 'meta/llama-3.3-70b-instruct',
        );
    }
  }
}
