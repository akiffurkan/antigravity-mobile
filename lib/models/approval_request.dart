import 'risk_level.dart';

enum ApprovalStatus {
  pending,
  approved,
  rejected,
  autoApproved,
  expired;

  String get label {
    switch (this) {
      case ApprovalStatus.pending:
        return 'Pending';
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
      case ApprovalStatus.autoApproved:
        return 'Auto-Approved';
      case ApprovalStatus.expired:
        return 'Expired';
    }
  }

  static ApprovalStatus fromString(String? value) {
    if (value == null) return ApprovalStatus.pending;
    switch (value.toLowerCase()) {
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      case 'auto_approved':
      case 'autoapproved':
        return ApprovalStatus.autoApproved;
      case 'expired':
        return ApprovalStatus.expired;
      default:
        return ApprovalStatus.pending;
    }
  }
}

class ApprovalRequest {
  final String id;
  final DateTime timestamp;
  final String sessionId;
  final String projectId;
  final String projectName;
  final String command;
  final String description;
  final String requestedAction;
  final RiskLevel riskLevel;
  final String? aiDecision;
  final String? aiReason;
  final double? aiConfidence;
  final ApprovalStatus status;
  final String source;
  final DateTime expiresAt;
  final bool requiresBiometric;
  final String nonce;

  const ApprovalRequest({
    required this.id,
    required this.timestamp,
    required this.sessionId,
    required this.projectId,
    required this.projectName,
    required this.command,
    required this.description,
    required this.requestedAction,
    required this.riskLevel,
    this.aiDecision,
    this.aiReason,
    this.aiConfidence,
    this.status = ApprovalStatus.pending,
    this.source = 'Antigravity PC',
    required this.expiresAt,
    this.requiresBiometric = false,
    required this.nonce,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == ApprovalStatus.pending && !isExpired;

  ApprovalRequest copyWith({
    String? id,
    DateTime? timestamp,
    String? sessionId,
    String? projectId,
    String? projectName,
    String? command,
    String? description,
    String? requestedAction,
    RiskLevel? riskLevel,
    String? aiDecision,
    String? aiReason,
    double? aiConfidence,
    ApprovalStatus? status,
    String? source,
    DateTime? expiresAt,
    bool? requiresBiometric,
    String? nonce,
  }) {
    return ApprovalRequest(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      command: command ?? this.command,
      description: description ?? this.description,
      requestedAction: requestedAction ?? this.requestedAction,
      riskLevel: riskLevel ?? this.riskLevel,
      aiDecision: aiDecision ?? this.aiDecision,
      aiReason: aiReason ?? this.aiReason,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      status: status ?? this.status,
      source: source ?? this.source,
      expiresAt: expiresAt ?? this.expiresAt,
      requiresBiometric: requiresBiometric ?? this.requiresBiometric,
      nonce: nonce ?? this.nonce,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'projectId': projectId,
      'projectName': projectName,
      'command': command,
      'description': description,
      'requestedAction': requestedAction,
      'riskLevel': riskLevel.name,
      'aiDecision': aiDecision,
      'aiReason': aiReason,
      'aiConfidence': aiConfidence,
      'status': status.name,
      'source': source,
      'expiresAt': expiresAt.toIso8601String(),
      'requiresBiometric': requiresBiometric,
      'nonce': nonce,
    };
  }

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sessionId: json['sessionId'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      projectName: json['projectName'] as String? ?? 'Antigravity Workspace',
      command: json['command'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requestedAction: json['requestedAction'] as String? ?? 'Execute Command',
      riskLevel: RiskLevel.fromString(json['riskLevel'] as String?),
      aiDecision: json['aiDecision'] as String?,
      aiReason: json['aiReason'] as String?,
      aiConfidence: (json['aiConfidence'] as num?)?.toDouble(),
      status: ApprovalStatus.fromString(json['status'] as String?),
      source: json['source'] as String? ?? 'Antigravity PC',
      expiresAt: DateTime.parse(
        json['expiresAt'] as String? ??
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      ),
      requiresBiometric: json['requiresBiometric'] as bool? ?? false,
      nonce: json['nonce'] as String? ?? '',
    );
  }
}
