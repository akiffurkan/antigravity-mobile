import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_mobile/core/security/security_validator.dart';
import 'package:antigravity_mobile/models/approval_request.dart';
import 'package:antigravity_mobile/models/device_info.dart';
import 'package:antigravity_mobile/models/risk_level.dart';

void main() {
  group('Security Validator & Action Security Tests', () {
    late SecurityValidator validator;

    final pairedDevice = DeviceInfo(
      id: 'pc-1',
      name: 'MacBook Pro',
      ipAddress: '192.168.1.10',
      port: 9400,
      isPaired: true,
      lastSeen: DateTime.now(),
      authToken: 'token_secret_123',
    );

    setUp(() {
      validator = SecurityValidator();
    });

    test('Valid pending request passes security validation', () {
      final request = ApprovalRequest(
        id: 'appr-valid',
        timestamp: DateTime.now(),
        sessionId: 'sess-1',
        projectId: 'p1',
        projectName: 'Antigravity Core',
        command: 'flutter test',
        description: 'Run unit tests',
        requestedAction: 'Execute Command',
        riskLevel: RiskLevel.low,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        nonce: 'nonce-valid-1',
      );

      final result = validator.validateApprovalAction(
        request: request,
        pairedDevice: pairedDevice,
        authToken: 'token_secret_123',
      );

      expect(result.isValid, isTrue);
    });

    test('Test 3: Expired request must be rejected', () {
      final expiredRequest = ApprovalRequest(
        id: 'appr-expired',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        sessionId: 'sess-1',
        projectId: 'p1',
        projectName: 'Antigravity Core',
        command: 'npm install',
        description: 'Old request',
        requestedAction: 'Execute Command',
        riskLevel: RiskLevel.low,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 2)), // Expired
        nonce: 'nonce-expired-1',
      );

      final result = validator.validateApprovalAction(
        request: expiredRequest,
        pairedDevice: pairedDevice,
        authToken: 'token_secret_123',
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, ValidationErrorCode.expired);
    });

    test('Test 4: Duplicate approval attempt on already processed request must be rejected', () {
      final request = ApprovalRequest(
        id: 'appr-dup',
        timestamp: DateTime.now(),
        sessionId: 'sess-1',
        projectId: 'p1',
        projectName: 'Antigravity Core',
        command: 'npm install lodash',
        description: 'First install',
        requestedAction: 'Execute Command',
        riskLevel: RiskLevel.low,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        nonce: 'nonce-dup-1',
      );

      // First validation succeeds
      final first = validator.validateApprovalAction(
        request: request,
        pairedDevice: pairedDevice,
        authToken: 'token_secret_123',
      );
      expect(first.isValid, isTrue);

      // Second validation with same request ID fails (Duplicate check)
      final second = validator.validateApprovalAction(
        request: request,
        pairedDevice: pairedDevice,
        authToken: 'token_secret_123',
      );
      expect(second.isValid, isFalse);
      expect(second.errorCode, ValidationErrorCode.alreadyProcessed);
    });

    test('Replay attack using same nonce with new request ID must be rejected', () {
      final request1 = ApprovalRequest(
        id: 'appr-orig',
        timestamp: DateTime.now(),
        sessionId: 'sess-1',
        projectId: 'p1',
        projectName: 'Project',
        command: 'echo hello',
        description: 'Run',
        requestedAction: 'Run',
        riskLevel: RiskLevel.low,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        nonce: 'replayed-nonce-xyz',
      );

      final result1 = validator.validateApprovalAction(
        request: request1,
        pairedDevice: pairedDevice,
        authToken: 'token_secret_123',
      );
      expect(result1.isValid, isTrue);

      final replayedRequest = ApprovalRequest(
        id: 'appr-forged',
        timestamp: DateTime.now(),
        sessionId: 'sess-1',
        projectId: 'p1',
        projectName: 'Project',
        command: 'echo pwned',
        description: 'Attacker injection',
        requestedAction: 'Run',
        riskLevel: RiskLevel.low,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        nonce: 'replayed-nonce-xyz', // Same nonce re-used!
      );

      final result2 = validator.validateApprovalAction(
        request: replayedRequest,
        pairedDevice: pairedDevice,
        authToken: 'token_secret_123',
      );
      expect(result2.isValid, isFalse);
      expect(result2.errorCode, ValidationErrorCode.replayAttackDetected);
    });

    test('Test 5: Unauthorized device or wrong token must be rejected', () {
      final request = ApprovalRequest(
        id: 'appr-unauth',
        timestamp: DateTime.now(),
        sessionId: 'sess-1',
        projectId: 'p1',
        projectName: 'Project',
        command: 'ls',
        description: 'List files',
        requestedAction: 'Run',
        riskLevel: RiskLevel.low,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        nonce: 'nonce-unauth-1',
      );

      // Wrong token
      final resultWrongToken = validator.validateApprovalAction(
        request: request,
        pairedDevice: pairedDevice,
        authToken: 'wrong_forged_token',
      );
      expect(resultWrongToken.isValid, isFalse);
      expect(resultWrongToken.errorCode, ValidationErrorCode.invalidToken);

      // Unpaired device
      final unpairedDevice = pairedDevice.copyWith(isPaired: false);
      final resultUnpaired = validator.validateApprovalAction(
        request: request,
        pairedDevice: unpairedDevice,
        authToken: 'token_secret_123',
      );
      expect(resultUnpaired.isValid, isFalse);
      expect(resultUnpaired.errorCode, ValidationErrorCode.unauthorizedDevice);
    });

    test('High risk request requiring biometric fails if biometric was not passed', () {
      final request = ApprovalRequest(
        id: 'appr-bio',
        timestamp: DateTime.now(),
        sessionId: 'sess-1',
        projectId: 'p1',
        projectName: 'Project',
        command: 'sudo rm -rf /tmp/data',
        description: 'Clean tmp',
        requestedAction: 'Run',
        riskLevel: RiskLevel.critical,
        requiresBiometric: true,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        nonce: 'nonce-bio-1',
      );

      final result = validator.validateApprovalAction(
        request: request,
        pairedDevice: pairedDevice,
        authToken: 'token_secret_123',
        biometricPassed: false,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, ValidationErrorCode.biometricRequired);
    });
  });
}
