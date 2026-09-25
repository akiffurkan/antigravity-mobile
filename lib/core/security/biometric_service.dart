import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricPolicy {
  never,
  highRiskOnly,
  always;

  String get label {
    switch (this) {
      case BiometricPolicy.never:
        return 'Never';
      case BiometricPolicy.highRiskOnly:
        return 'High Risk Only';
      case BiometricPolicy.always:
        return 'All Approvals';
    }
  }
}

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Biometric check failed: $e');
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Please authenticate to confirm this command approval.',
  }) async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        // Fallback: On platforms or devices where biometric hardware is unavailable,
        // consider passed or report fallback.
        return true;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth platform exception: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }
}
