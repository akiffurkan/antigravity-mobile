import 'dart:async';
import 'dart:convert';
import '../../models/approval_request.dart';
import '../../models/risk_level.dart';
import '../../models/chat_message.dart';
import '../../models/connection_state.dart';
import '../../models/device_info.dart';
import '../../models/session.dart';
import '../connection/connection_manager.dart';
import 'antigravity_bridge.dart';

class TransportAntigravityBridge implements AntigravityBridge {
  final ConnectionManager connectionManager;

  final _connectionStateController =
      StreamController<BridgeConnectionState>.broadcast();
  final _approvalController = StreamController<ApprovalRequest>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();

  BridgeConnectionState _currentState = BridgeConnectionState.disconnected;
  StreamSubscription? _statusSub;
  StreamSubscription? _wifiDataSub;
  StreamSubscription? _btDataSub;

  final Map<String, Completer<dynamic>> _pendingRequests = {};
  int _reqId = 0;

  TransportAntigravityBridge({required this.connectionManager}) {
    _statusSub = connectionManager.statusStream.listen(_onStatusChanged);
    _wifiDataSub =
        connectionManager.wifiTransport.incomingDataStream.listen(_onData);
    _btDataSub =
        connectionManager.bluetoothTransport.incomingDataStream.listen(_onData);
  }

  void _onStatusChanged(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        _currentState = BridgeConnectionState.connected;
        break;
      case ConnectionStatus.connecting:
      case ConnectionStatus.searching:
        _currentState = BridgeConnectionState.connecting;
        break;
      case ConnectionStatus.reconnecting:
        _currentState = BridgeConnectionState.reconnecting;
        break;
      case ConnectionStatus.offline:
      case ConnectionStatus.authFailed:
      case ConnectionStatus.pairingRequired:
        _currentState = BridgeConnectionState.disconnected;
        break;
    }
    _connectionStateController.add(_currentState);
  }

  void _onData(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (data.containsKey('requestId')) {
        final reqId = data['requestId'] as String;
        if (_pendingRequests.containsKey(reqId)) {
          _pendingRequests.remove(reqId)!.complete(data['result']);
          return;
        }
      }

      switch (type) {
        case 'status':
          if (data['payload'] is Map<String, dynamic>) {
            final payload = data['payload'] as Map<String, dynamic>;
            if (payload['status'] == 'connected') {
              _currentState = BridgeConnectionState.connected;
              _connectionStateController.add(_currentState);
            }
          }
          break;

        case 'heartbeat':
          if (_currentState != BridgeConnectionState.connected) {
            _currentState = BridgeConnectionState.connected;
            _connectionStateController.add(_currentState);
          }
          break;

        case 'approval_request':
          final approval = ApprovalRequest.fromJson(
            data['payload'] as Map<String, dynamic>,
          );
          _approvalController.add(approval);
          break;

        case 'approval_resolved':
          if (data['payload'] is Map<String, dynamic>) {
            final p = data['payload'] as Map<String, dynamic>;
            final apprId = p['id'] as String?;
            final statusStr = p['status'] as String? ?? p['decision'] as String?;
            final status = statusStr == 'approved'
                ? ApprovalStatus.approved
                : ApprovalStatus.rejected;
            if (apprId != null) {
              _approvalController.add(
                ApprovalRequest(
                  id: apprId,
                  timestamp: DateTime.now(),
                  sessionId: p['sessionId'] as String? ?? '',
                  projectId: p['projectId'] as String? ?? '',
                  projectName: p['projectName'] as String? ?? 'Antigravity Workspace',
                  command: p['command'] as String? ?? '',
                  description: p['description'] as String? ?? '',
                  requestedAction: p['requestedAction'] as String? ?? 'Execute Command',
                  riskLevel: RiskLevel.medium,
                  status: status,
                  source: 'PC Bridge',
                  expiresAt: DateTime.now().add(const Duration(hours: 1)),
                  nonce: '',
                ),
              );
            }
          }
          break;

        case 'chat_message':
          final message = ChatMessage.fromJson(
            data['payload'] as Map<String, dynamic>,
          );
          _messageController.add(message);
          break;
      }
    } catch (_) {}
  }

  @override
  BridgeConnectionState get currentConnectionState => _currentState;

  @override
  Stream<BridgeConnectionState> get connectionState async* {
    yield _currentState;
    yield* _connectionStateController.stream;
  }

  @override
  Stream<ApprovalRequest> get approvalRequests => _approvalController.stream;

  @override
  Stream<ChatMessage> get messageStream => _messageController.stream;

  @override
  Future<void> connect({DeviceInfo? device}) async {
    await connectionManager.connect(device: device);
  }

  @override
  Future<void> disconnect() async {
    await connectionManager.disconnect();
  }

  @override
  Future<List<Session>> getSessions() async {
    if (_currentState != BridgeConnectionState.connected) return [];
    final res = await _send('get_sessions', {});
    if (res is List) {
      return res
          .map((i) => Session.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    if (_currentState != BridgeConnectionState.connected) return [];
    final res = await _send('get_messages', {'sessionId': sessionId});
    if (res is List) {
      return res
          .map((i) => ChatMessage.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<void> sendMessage(String sessionId, String message) async {
    await _send('send_message', {
      'sessionId': sessionId,
      'content': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> approve(String approvalId) async {
    await _send('approval_decision', {
      'approvalId': approvalId,
      'decision': 'approved',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> reject(String approvalId) async {
    await _send('approval_decision', {
      'approvalId': approvalId,
      'decision': 'rejected',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<ApprovalRequest>> getPendingApprovals() async {
    if (_currentState != BridgeConnectionState.connected) return [];
    final res = await _send('get_approvals', {});
    if (res is List) {
      return res
          .map((i) => ApprovalRequest.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<dynamic> _send(String action, Map<String, dynamic> payload) {
    final id = 'req_${++_reqId}';
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    final msg = jsonEncode({
      'type': 'request',
      'action': action,
      'requestId': id,
      'payload': payload,
    });

    if (connectionManager.activeTransport == ConnectionTransportType.wifi) {
      connectionManager.wifiTransport.sendData(msg);
    } else {
      connectionManager.bluetoothTransport.sendData(msg);
    }

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Bridge request $action timed out.');
      },
    );
  }

  void dispose() {
    _statusSub?.cancel();
    _wifiDataSub?.cancel();
    _btDataSub?.cancel();
    _connectionStateController.close();
    _approvalController.close();
    _messageController.close();
  }
}
