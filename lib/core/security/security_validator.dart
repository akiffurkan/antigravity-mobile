import '../../models/approval_request.dart';
import '../../models/device_info.dart';

enum ValidationErrorCode {
  requestNotFound,
  alreadyProcessed,
  expired,
  replayAttackDetected,
  unauthorizedDevice,
  invalidToken,
  biometricRequired,
}

class SecurityValidationResult {
  final bool isValid;
  final ValidationErrorCode? errorCode;
  final String message;

  const SecurityValidationResult.success()
      : isValid = true,
        errorCode = null,
        message = 'Validation successful.';

  const SecurityValidationResult.failure(this.errorCode, this.message)
      : isValid = false;
}

class SecurityValidator {
  final Set<String> _processedNonces = {};
  final Set<String> _processedApprovalIds = {};

  /// Validates an incoming approval action before dispatching to the Antigravity Bridge.
  SecurityValidationResult validateApprovalAction({
    required ApprovalRequest? request,
    required DeviceInfo? pairedDevice,
    required String? authToken,
    bool biometricPassed = false,
  }) {
    // 1. Check if request exists
    if (request == null) {
      return const SecurityValidationResult.failure(
        ValidationErrorCode.requestNotFound,
        'Approval request not found or has been revoked.',
      );
    }

    // 2. Check if already processed in memory / cache
    if (_processedApprovalIds.contains(request.id) ||
        request.status != ApprovalStatus.pending) {
      return const SecurityValidationResult.failure(
        ValidationErrorCode.alreadyProcessed,
        'This request has already been processed or completed.',
      );
    }

    // 3. Expiration Check
    if (request.isExpired) {
      return const SecurityValidationResult.failure(
        ValidationErrorCode.expired,
        'This approval request has expired and cannot be actioned.',
      );
    }

    // 4. Replay Protection (Check nonce uniqueness)
    if (_processedNonces.contains(request.nonce)) {
      return const SecurityValidationResult.failure(
        ValidationErrorCode.replayAttackDetected,
        'Replay attack detected: Nonce has already been consumed.',
      );
    }

    // 5. Device Authorization & Token Check
    if (pairedDevice == null || !pairedDevice.isPaired) {
      return const SecurityValidationResult.failure(
        ValidationErrorCode.unauthorizedDevice,
        'No authorized companion device paired.',
      );
    }

    if (pairedDevice.authToken != null &&
        pairedDevice.authToken != authToken) {
      return const SecurityValidationResult.failure(
        ValidationErrorCode.invalidToken,
        'Device authentication token is invalid or mismatched.',
      );
    }

    // 6. Biometric Requirement Check
    if (request.requiresBiometric && !biometricPassed) {
      return const SecurityValidationResult.failure(
        ValidationErrorCode.biometricRequired,
        'Biometric authentication is strictly required for this approval.',
      );
    }

    // Record consumption
    _processedNonces.add(request.nonce);
    _processedApprovalIds.add(request.id);

    return const SecurityValidationResult.success();
  }

  void reset() {
    _processedNonces.clear();
    _processedApprovalIds.clear();
  }
}
