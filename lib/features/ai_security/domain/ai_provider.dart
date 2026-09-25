import '../../../models/approval_request.dart';
import '../../../models/security_decision.dart';

enum AIProviderType {
  openAI,
  gemini,
  nvidiaNim;

  String get displayName {
    switch (this) {
      case AIProviderType.openAI:
        return 'OpenAI';
      case AIProviderType.gemini:
        return 'Google Gemini';
      case AIProviderType.nvidiaNim:
        return 'NVIDIA NIM';
    }
  }

  List<String> get availableModels {
    switch (this) {
      case AIProviderType.openAI:
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo'];
      case AIProviderType.gemini:
        return ['gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'];
      case AIProviderType.nvidiaNim:
        return ['meta/llama-3.3-70b-instruct', 'mistralai/mixtral-8x22b-instruct'];
    }
  }
}

/// Abstract AI Security Provider interface.
/// Encapsulates model analysis, structured JSON parsing, and fail-safe policy.
abstract class AIProvider {
  String get name;
  String get modelName;

  /// Analyzes a command and returns a structured SecurityDecision.
  /// If any error occurs (network failure, invalid format, timeout),
  /// MUST return a fallback requiring user confirmation. NEVER auto-approves on error.
  Future<SecurityDecision> analyzeCommand(ApprovalRequest request);
}
