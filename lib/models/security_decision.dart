enum RiskMode {
  conservative,
  balanced,
  permissive;

  String get label {
    switch (this) {
      case RiskMode.conservative:
        return 'Conservative';
      case RiskMode.balanced:
        return 'Balanced';
      case RiskMode.permissive:
        return 'Permissive';
    }
  }
}

class SecurityDecision {
  final String decision; // 'LOW_RISK', 'HIGH_RISK', 'UNKNOWN'
  final double confidence;
  final String reason;
  final bool requiresUserConfirmation;

  const SecurityDecision({
    required this.decision,
    required this.confidence,
    required this.reason,
    required this.requiresUserConfirmation,
  });

  bool get isLowRisk => decision == 'LOW_RISK' && !requiresUserConfirmation;
  bool get isHighRisk => decision == 'HIGH_RISK';
  bool get isUnknown => decision == 'UNKNOWN';

  static const SecurityDecision fallback = SecurityDecision(
    decision: 'UNKNOWN',
    confidence: 0.0,
    reason: 'Security analysis could not verify command safety. Manual user approval required.',
    requiresUserConfirmation: true,
  );

  Map<String, dynamic> toJson() {
    return {
      'decision': decision,
      'confidence': confidence,
      'reason': reason,
      'requires_user_confirmation': requiresUserConfirmation,
    };
  }

  factory SecurityDecision.fromJson(Map<String, dynamic> json) {
    return SecurityDecision(
      decision: json['decision'] as String? ?? 'UNKNOWN',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? 'No reasoning provided',
      requiresUserConfirmation:
          json['requires_user_confirmation'] as bool? ?? true,
    );
  }
}
