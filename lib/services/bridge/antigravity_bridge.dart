import 'dart:async';
import '../../models/approval_request.dart';
import '../../models/chat_message.dart';
import '../../models/session.dart';

enum BridgeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

abstract class AntigravityBridge {
  Future<void> connect();
  Future<void> disconnect();

  Stream<BridgeConnectionState> get connectionState;
  BridgeConnectionState get currentConnectionState;

  Future<List<Session>> getSessions();

  Future<List<ChatMessage>> getMessages(String sessionId);

  Future<void> sendMessage(String sessionId, String message);

  Stream<ApprovalRequest> get approvalRequests;
  Stream<ChatMessage> get messageStream;

  Future<List<ApprovalRequest>> getPendingApprovals();

  Future<void> approve(String approvalId);

  Future<void> reject(String approvalId);
}
