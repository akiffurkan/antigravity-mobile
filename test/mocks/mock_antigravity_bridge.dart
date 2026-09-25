import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:antigravity_mobile/models/approval_request.dart';
import 'package:antigravity_mobile/models/chat_message.dart';
import 'package:antigravity_mobile/models/risk_level.dart';
import 'package:antigravity_mobile/models/session.dart';
import 'package:antigravity_mobile/models/device_info.dart';
import 'package:antigravity_mobile/services/bridge/antigravity_bridge.dart';

/// Test fixture mock bridge used exclusively for unit testing
class MockAntigravityBridge implements AntigravityBridge {
  static const _uuid = Uuid();

  final _connectionStateController =
      StreamController<BridgeConnectionState>.broadcast();
  final _approvalController = StreamController<ApprovalRequest>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();

  BridgeConnectionState _currentState = BridgeConnectionState.disconnected;

  List<Session> _sessions = [];
  final Map<String, List<ChatMessage>> _messagesBySession = {};
  final List<ApprovalRequest> _pendingApprovals = [];

  MockAntigravityBridge() {
    _initializeMockData();
  }

  void _initializeMockData() {
    final now = DateTime.now();

    _sessions = [
      Session(
        id: 'sess-alpha',
        title: 'Project Alpha (Core API)',
        projectName: 'antigravity-core',
        projectPath: '~/workspace/antigravity-core',
        status: SessionStatus.waitingApproval,
        createdAt: now.subtract(const Duration(hours: 2)),
        lastActiveAt: now.subtract(const Duration(minutes: 2)),
        pendingApprovalCount: 1,
        lastMessagePreview: 'npm install express dotenv',
      ),
      Session(
        id: 'sess-mobile',
        title: 'Flutter Companion App',
        projectName: 'antigravity_mobile',
        projectPath: 'c:/Users/akiff/Desktop/Antigravity Mobil',
        status: SessionStatus.active,
        createdAt: now.subtract(const Duration(hours: 5)),
        lastActiveAt: now.subtract(const Duration(minutes: 10)),
        pendingApprovalCount: 0,
        lastMessagePreview: 'Running flutter pub get...',
      ),
    ];

    _messagesBySession['sess-alpha'] = [
      ChatMessage(
        id: 'msg-1',
        sessionId: 'sess-alpha',
        role: MessageRole.user,
        content: 'Please add express and dotenv to handle the HTTP endpoints.',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      ChatMessage(
        id: 'msg-2',
        sessionId: 'sess-alpha',
        role: MessageRole.antigravity,
        content: 'I will update package.json.',
        timestamp: now.subtract(const Duration(minutes: 4)),
      ),
    ];

    final initialApproval = ApprovalRequest(
      id: 'appr-demo-1',
      timestamp: now.subtract(const Duration(minutes: 3)),
      sessionId: 'sess-alpha',
      projectId: 'antigravity-core',
      projectName: 'Project Alpha',
      command: 'npm install express dotenv',
      description: 'Installs production HTTP routing and environment variable modules.',
      requestedAction: 'Execute Terminal Command',
      riskLevel: RiskLevel.low,
      aiDecision: 'LOW_RISK',
      aiConfidence: 0.96,
      aiReason: 'Standard npm package installation.',
      status: ApprovalStatus.pending,
      source: 'Antigravity PC Test',
      expiresAt: now.add(const Duration(minutes: 15)),
      requiresBiometric: false,
      nonce: _uuid.v4(),
    );
    _pendingApprovals.add(initialApproval);
  }

  @override
  BridgeConnectionState get currentConnectionState => _currentState;

  @override
  Stream<BridgeConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  Stream<ApprovalRequest> get approvalRequests => _approvalController.stream;

  @override
  Stream<ChatMessage> get messageStream => _messageController.stream;

  @override
  Future<void> connect({DeviceInfo? device}) async {
    _currentState = BridgeConnectionState.connecting;
    _connectionStateController.add(_currentState);

    await Future.delayed(const Duration(milliseconds: 50));

    _currentState = BridgeConnectionState.connected;
    _connectionStateController.add(_currentState);

    for (final appr in _pendingApprovals) {
      if (appr.isPending) {
        _approvalController.add(appr);
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _currentState = BridgeConnectionState.disconnected;
    _connectionStateController.add(_currentState);
  }

  @override
  Future<List<Session>> getSessions() async {
    return List.unmodifiable(_sessions);
  }

  @override
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    return List.unmodifiable(_messagesBySession[sessionId] ?? []);
  }

  @override
  Future<void> sendMessage(String sessionId, String message) async {
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      sessionId: sessionId,
      role: MessageRole.user,
      content: message,
      timestamp: DateTime.now(),
    );

    _messagesBySession.putIfAbsent(sessionId, () => []).add(userMsg);
    _messageController.add(userMsg);
  }

  @override
  Future<void> approve(String approvalId) async {
    final index = _pendingApprovals.indexWhere((a) => a.id == approvalId);
    if (index != -1) {
      final updated = _pendingApprovals[index].copyWith(
        status: ApprovalStatus.approved,
      );
      _pendingApprovals[index] = updated;
      _approvalController.add(updated);
    }
  }

  @override
  Future<void> reject(String approvalId) async {
    final index = _pendingApprovals.indexWhere((a) => a.id == approvalId);
    if (index != -1) {
      final updated = _pendingApprovals[index].copyWith(
        status: ApprovalStatus.rejected,
      );
      _pendingApprovals[index] = updated;
      _approvalController.add(updated);
    }
  }

  @override
  Future<List<ApprovalRequest>> getPendingApprovals() async {
    return List.unmodifiable(_pendingApprovals.where((a) => a.isPending).toList());
  }

  /// Helper for unit tests
  ApprovalRequest triggerDemoApproval({
    required String command,
    required RiskLevel riskLevel,
    required String projectName,
  }) {
    final now = DateTime.now();
    final newApproval = ApprovalRequest(
      id: 'appr-${_uuid.v4().substring(0, 8)}',
      timestamp: now,
      sessionId: 'sess-alpha',
      projectId: 'test-project',
      projectName: projectName,
      command: command,
      description: 'Unit test approval request.',
      requestedAction: 'Execute Command',
      riskLevel: riskLevel,
      status: ApprovalStatus.pending,
      source: 'Test Runner',
      expiresAt: now.add(const Duration(minutes: 10)),
      nonce: _uuid.v4(),
    );
    _pendingApprovals.add(newApproval);
    _approvalController.add(newApproval);
    return newApproval;
  }

  List<ApprovalRequest> get allApprovals => List.unmodifiable(_pendingApprovals);
}
