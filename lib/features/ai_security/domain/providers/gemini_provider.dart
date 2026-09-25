import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:antigravity_mobile/models/approval_request.dart';
import 'package:antigravity_mobile/models/security_decision.dart';
import '../ai_provider.dart';

class GeminiProvider implements AIProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-2.0-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Google Gemini';

  @override
  String get modelName => model;

  @override
  Future<SecurityDecision> analyzeCommand(ApprovalRequest request) async {
    if (apiKey.isEmpty) {
      return const SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'Gemini API key is missing. Manual approval required.',
        requiresUserConfirmation: true,
      );
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      final prompt = '''
You are a developer security assistant analyzing commands requested by an IDE agent.
Respond ONLY with valid JSON conforming to this schema:
{
  "decision": "LOW_RISK" | "HIGH_RISK" | "UNKNOWN",
  "confidence": 0.0 to 1.0,
  "reason": "Clear security justification",
  "requires_user_confirmation": true | false
}

Command: ${request.command}
Project: ${request.projectName}
Action: ${request.requestedAction}
Description: ${request.description}
''';

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                'temperature': 0.1,
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = body['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content']?['parts']?[0]?['text'] as String?;
          if (content != null) {
            final jsonMap = jsonDecode(content) as Map<String, dynamic>;
            return SecurityDecision.fromJson(jsonMap);
          }
        }
      }

      return SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'Gemini API returned status ${response.statusCode}. Manual approval required.',
        requiresUserConfirmation: true,
      );
    } on TimeoutException {
      return const SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'Gemini API timed out. Manual approval required.',
        requiresUserConfirmation: true,
      );
    } catch (e) {
      return SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'Gemini analysis failed: $e. Manual approval required.',
        requiresUserConfirmation: true,
      );
    }
  }
}
