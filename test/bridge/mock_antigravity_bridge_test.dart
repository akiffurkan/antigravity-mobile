import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_mobile/models/approval_request.dart';
import 'package:antigravity_mobile/models/risk_level.dart';
import 'package:antigravity_mobile/services/bridge/antigravity_bridge.dart';
import '../mocks/mock_antigravity_bridge.dart';

void main() {
  group('MockAntigravityBridge Tests', () {
    late MockAntigravityBridge bridge;

    setUp(() {
      bridge = MockAntigravityBridge();
    });

    test('Initial connection lifecycle updates connection state', () async {
      expect(bridge.currentConnectionState, BridgeConnectionState.disconnected);

      final stateFuture = bridge.connectionState.take(2).toList();
      await bridge.connect();

      final states = await stateFuture;
      expect(states, contains(BridgeConnectionState.connecting));
      expect(states, contains(BridgeConnectionState.connected));
      expect(bridge.currentConnectionState, BridgeConnectionState.connected);
    });

    test('getSessions returns seeded mock sessions', () async {
      final sessions = await bridge.getSessions();
      expect(sessions, isNotEmpty);
      expect(sessions.any((s) => s.id == 'sess-alpha'), isTrue);
    });

    test('sendMessage appends user message and returns simulated response', () async {
      final initialMessages = await bridge.getMessages('sess-alpha');
      final initialCount = initialMessages.length;

      await bridge.sendMessage('sess-alpha', 'Test prompt message');

      final updatedMessages = await bridge.getMessages('sess-alpha');
      expect(updatedMessages.length, initialCount + 1);
      expect(updatedMessages.last.content, 'Test prompt message');
    });

    test('Approve and Reject modify approval request status', () async {
      final demoApproval = bridge.triggerDemoApproval(
        command: 'flutter run',
        riskLevel: RiskLevel.low,
        projectName: 'Mobile App',
      );

      expect(demoApproval.status, ApprovalStatus.pending);

      await bridge.approve(demoApproval.id);
      final approvedItem =
          bridge.allApprovals.firstWhere((a) => a.id == demoApproval.id);
      expect(approvedItem.status, ApprovalStatus.approved);

      final secondDemo = bridge.triggerDemoApproval(
        command: 'rm important.txt',
        riskLevel: RiskLevel.high,
        projectName: 'Mobile App',
      );

      await bridge.reject(secondDemo.id);
      final rejectedItem =
          bridge.allApprovals.firstWhere((a) => a.id == secondDemo.id);
      expect(rejectedItem.status, ApprovalStatus.rejected);
    });
  });
}
