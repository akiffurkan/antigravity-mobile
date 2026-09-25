import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:antigravity_mobile/features/ai_security/domain/providers/gemini_provider.dart';
import 'package:antigravity_mobile/features/ai_security/domain/providers/openai_provider.dart';
import 'package:antigravity_mobile/models/approval_request.dart';
import 'package:antigravity_mobile/models/risk_level.dart';

void main() {
  group('AI Provider & Failure Policy Tests', () {
    final sampleRequest = ApprovalRequest(
      id: 'appr-sample',
      timestamp: DateTime.now(),
      sessionId: 'sess-1',
      projectId: 'p1',
      projectName: 'Alpha',
      command: 'npm install express',
      description: 'Install express',
      requestedAction: 'Run',
      riskLevel: RiskLevel.low,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      nonce: 'nonce-sample',
    );

    test('OpenAI Provider parses structured valid JSON response properly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'decision': 'LOW_RISK',
                    'confidence': 0.95,
                    'reason': 'Installs safe well-known npm library.',
                    'requires_user_confirmation': false,
                  }),
                }
              }
            ]
          }),
          200,
        );
      });

      final provider = OpenAIProvider(apiKey: 'mock-key', client: mockClient);
      final decision = await provider.analyzeCommand(sampleRequest);

      expect(decision.decision, 'LOW_RISK');
      expect(decision.confidence, 0.95);
      expect(decision.requiresUserConfirmation, isFalse);
    });

    test('Test 2: OpenAI Provider returns UNKNOWN on HTTP 500 error (Never auto-approves)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final provider = OpenAIProvider(apiKey: 'mock-key', client: mockClient);
      final decision = await provider.analyzeCommand(sampleRequest);

      expect(decision.decision, 'UNKNOWN');
      expect(decision.requiresUserConfirmation, isTrue);
      expect(decision.isLowRisk, isFalse);
    });

    test('OpenAI Provider returns UNKNOWN on missing API key', () async {
      final provider = OpenAIProvider(apiKey: '');
      final decision = await provider.analyzeCommand(sampleRequest);

      expect(decision.decision, 'UNKNOWN');
      expect(decision.requiresUserConfirmation, isTrue);
    });

    test('Gemini Provider handles malformed JSON response safely (Fail-safe to UNKNOWN)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'This is NOT valid JSON syntax {{{'}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final provider = GeminiProvider(apiKey: 'mock-gemini-key', client: mockClient);
      final decision = await provider.analyzeCommand(sampleRequest);

      expect(decision.decision, 'UNKNOWN');
      expect(decision.requiresUserConfirmation, isTrue);
    });
  });
}
