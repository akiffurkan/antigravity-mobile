import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:antigravity_mobile/models/approval_request.dart';
import 'package:antigravity_mobile/models/security_decision.dart';
import '../ai_provider.dart';

class OpenAIProvider implements AIProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  OpenAIProvider({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'OpenAI';

  @override
  String get modelName => model;

  @override
  Future<SecurityDecision> analyzeCommand(ApprovalRequest request) async {
    if (apiKey.isEmpty) {
      return const SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'OpenAI API key is missing. Manual approval required.',
        requiresUserConfirmation: true,
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'response_format': {'type': 'json_object'},
              'messages': [
                {
                  'role': 'system',
                  'content': '''
You are a Linux & Windows system security expert analyzing terminal commands requested by an AI developer assistant.
Evaluate the command safety. Respond with JSON strictly matching:
{
  "decision": "LOW_RISK" | "HIGH_RISK" | "UNKNOWN",
  "confidence": 0.0 to 1.0,
  "reason": "Brief explanation of command risk and impact",
  "requires_user_confirmation": true | false
}
Rules:
- Standard read-only, formatting, or common package installs (npm install, flutter pub) can be LOW_RISK.
- Any command with sudo, rm -rf, disk writes, ssh, or secret access MUST be HIGH_RISK with requires_user_confirmation = true.
- If unsure, use UNKNOWN with requires_user_confirmation = true.
'''
                },
                {
                  'role': 'user',
                  'content': jsonEncode({
                    'command': request.command,
                    'project': request.projectName,
                    'action': request.requestedAction,
                    'description': request.description,
                  }),
                }
              ],
              'temperature': 0.1,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = body['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final contentStr = choices[0]['message']['content'] as String;
          final jsonMap = jsonDecode(contentStr) as Map<String, dynamic>;
          return SecurityDecision.fromJson(jsonMap);
        }
      }

      // Non-200 or unexpected structure -> Fail safe
      return SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'OpenAI API returned status ${response.statusCode}. Manual approval required.',
        requiresUserConfirmation: true,
      );
    } on TimeoutException {
      return const SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'OpenAI API timed out. Manual approval required.',
        requiresUserConfirmation: true,
      );
    } catch (e) {
      return SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'AI analysis encountered error: $e. Manual approval required.',
        requiresUserConfirmation: true,
      );
    }
  }
}
