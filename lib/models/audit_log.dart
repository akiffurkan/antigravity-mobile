import 'risk_level.dart';

enum DecisionType {
  userApproved,
  userRejected,
  autoApproved,
  policyBlocked,
  expired,
  replayRejected;

  String get label {
    switch (this) {
      case DecisionType.userApproved:
        return 'USER_APPROVED';
      case DecisionType.userRejected:
        return 'USER_REJECTED';
      case DecisionType.autoApproved:
        return 'AUTO_APPROVED';
      case DecisionType.policyBlocked:
        return 'POLICY_BLOCKED';
      case DecisionType.expired:
        return 'EXPIRED';
      case DecisionType.replayRejected:
        return 'REPLAY_REJECTED';
    }
  }
}

class AuditLog {
  final String id;
  final DateTime timestamp;
  final String approvalRequestId;
  final String projectName;
  final String command;
  final DecisionType decision;
  final RiskLevel riskLevel;
  final String reason;
  final String? aiProvider;
  final String? aiModel;
  final String user;

  const AuditLog({
    required this.id,
    required this.timestamp,
    required this.approvalRequestId,
    required this.projectName,
    required this.command,
    required this.decision,
    required this.riskLevel,
    required this.reason,
    this.aiProvider,
    this.aiModel,
    this.user = 'Local User',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'approvalRequestId': approvalRequestId,
      'projectName': projectName,
      'command': command,
      'decision': decision.name,
      'riskLevel': riskLevel.name,
      'reason': reason,
      'aiProvider': aiProvider,
      'aiModel': aiModel,
      'user': user,
    };
  }

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      approvalRequestId: json['approvalRequestId'] as String,
      projectName: json['projectName'] as String? ?? 'Workspace',
      command: json['command'] as String? ?? '',
      decision: DecisionType.values.firstWhere(
        (e) => e.name == json['decision'],
        orElse: () => DecisionType.userApproved,
      ),
      riskLevel: RiskLevel.fromString(json['riskLevel'] as String?),
      reason: json['reason'] as String? ?? '',
      aiProvider: json['aiProvider'] as String?,
      aiModel: json['aiModel'] as String?,
      user: json['user'] as String? ?? 'Local User',
    );
  }
}
