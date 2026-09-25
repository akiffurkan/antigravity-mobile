enum SessionStatus {
  active,
  idle,
  waitingApproval,
  completed,
}

class Session {
  final String id;
  final String title;
  final String projectName;
  final String projectPath;
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final int pendingApprovalCount;
  final String? lastMessagePreview;

  const Session({
    required this.id,
    required this.title,
    required this.projectName,
    required this.projectPath,
    this.status = SessionStatus.active,
    required this.createdAt,
    required this.lastActiveAt,
    this.pendingApprovalCount = 0,
    this.lastMessagePreview,
  });

  Session copyWith({
    String? id,
    String? title,
    String? projectName,
    String? projectPath,
    SessionStatus? status,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    int? pendingApprovalCount,
    String? lastMessagePreview,
  }) {
    return Session(
      id: id ?? this.id,
      title: title ?? this.title,
      projectName: projectName ?? this.projectName,
      projectPath: projectPath ?? this.projectPath,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      pendingApprovalCount: pendingApprovalCount ?? this.pendingApprovalCount,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'projectName': projectName,
      'projectPath': projectPath,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'pendingApprovalCount': pendingApprovalCount,
      'lastMessagePreview': lastMessagePreview,
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      title: json['title'] as String,
      projectName: json['projectName'] as String? ?? 'Workspace',
      projectPath: json['projectPath'] as String? ?? '',
      status: SessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SessionStatus.active,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
      pendingApprovalCount: json['pendingApprovalCount'] as int? ?? 0,
      lastMessagePreview: json['lastMessagePreview'] as String?,
    );
  }
}
