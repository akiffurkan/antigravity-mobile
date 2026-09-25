import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:antigravity_mobile/models/approval_request.dart';
import 'package:antigravity_mobile/models/security_decision.dart';
import '../ai_provider.dart';

class NvidiaNimProvider implements AIProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  NvidiaNimProvider({
    required this.apiKey,
    this.model = 'meta/llama-3.3-70b-instruct',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'NVIDIA NIM';

  @override
  String get modelName => model;

  @override
  Future<SecurityDecision> analyzeCommand(ApprovalRequest request) async {
    if (apiKey.isEmpty) {
      return const SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'NVIDIA NIM API key is missing. Manual approval required.',
        requiresUserConfirmation: true,
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
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
Analyze the terminal command safety for an IDE assistant. Return strict JSON:
{
  "decision": "LOW_RISK" | "HIGH_RISK" | "UNKNOWN",
  "confidence": 0.0 to 1.0,
  "reason": "Clear explanation",
  "requires_user_confirmation": true | false
}
'''
                },
                {
                  'role': 'user',
                  'content': jsonEncode({
                    'command': request.command,
                    'project': request.projectName,
                    'action': request.requestedAction,
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

      return SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'NVIDIA NIM returned HTTP ${response.statusCode}. Manual approval required.',
        requiresUserConfirmation: true,
      );
    } on TimeoutException {
      return const SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'NVIDIA NIM API timed out. Manual approval required.',
        requiresUserConfirmation: true,
      );
    } catch (e) {
      return SecurityDecision(
        decision: 'UNKNOWN',
        confidence: 0.0,
        reason: 'NVIDIA NIM analysis failed: $e. Manual approval required.',
        requiresUserConfirmation: true,
      );
    }
  }
}
