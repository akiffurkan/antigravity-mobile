import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/approval_request.dart';
import '../../models/chat_message.dart';
import '../../models/session.dart';
import 'antigravity_bridge.dart';

class WebSocketAntigravityBridge implements AntigravityBridge {
  final String host;
  final int port;
  final String? authToken;
  final String clientId;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;

  final _connectionStateController =
      StreamController<BridgeConnectionState>.broadcast();
  final _approvalController = StreamController<ApprovalRequest>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();

  BridgeConnectionState _currentState = BridgeConnectionState.disconnected;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  final Map<String, Completer<dynamic>> _pendingRequests = {};
  int _reqId = 0;

  WebSocketAntigravityBridge({
    required this.host,
    this.port = 9400,
    this.authToken,
    this.clientId = 'antigravity-mobile-client',
  });

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
  Future<void> connect() async {
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    _setConnectionState(BridgeConnectionState.connecting);

    try {
      final uri = Uri.parse('ws://$host:$port/bridge');
      _channel = WebSocketChannel.connect(uri);

      // Authenticate handshake payload
      final handshake = {
        'type': 'handshake',
        'clientId': clientId,
        'authToken': authToken,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _channel?.sink.add(jsonEncode(handshake));

      _channelSub = _channel?.stream.listen(
        _onMessageReceived,
        onError: (err) {
          debugPrint('WebSocket error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed.');
          _handleDisconnect();
        },
      );

      _setConnectionState(BridgeConnectionState.connected);
      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      _handleDisconnect();
    }
  }

  void _onMessageReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (data.containsKey('requestId')) {
        final reqId = data['requestId'] as String;
        if (_pendingRequests.containsKey(reqId)) {
          _pendingRequests.remove(reqId)!.complete(data['result']);
          return;
        }
      }

      switch (type) {
        case 'approval_request':
          final approval = ApprovalRequest.fromJson(
            data['payload'] as Map<String, dynamic>,
          );
          _approvalController.add(approval);
          break;

        case 'chat_message':
          final message = ChatMessage.fromJson(
            data['payload'] as Map<String, dynamic>,
          );
          _messageController.add(message);
          break;

        case 'ping':
          _channel?.sink.add(jsonEncode({'type': 'pong'}));
          break;
      }
    } catch (e) {
      debugPrint('Error processing bridge message: $e');
    }
  }

  void _handleDisconnect() {
    _setConnectionState(BridgeConnectionState.disconnected);

    if (_shouldReconnect) {
      _setConnectionState(BridgeConnectionState.reconnecting);
      final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), 30);
      _reconnectAttempts++;

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (_shouldReconnect) {
          _establishConnection();
        }
      });
    }
  }

  void _setConnectionState(BridgeConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  @override
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    await _channelSub?.cancel();
    await _channel?.sink.close();
    _setConnectionState(BridgeConnectionState.disconnected);
  }

  @override
  Future<List<Session>> getSessions() async {
    if (_currentState != BridgeConnectionState.connected) {
      return [];
    }
    final result = await _sendRequest('get_sessions', {});
    if (result is List) {
      return result
          .map((item) => Session.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    if (_currentState != BridgeConnectionState.connected) {
      return [];
    }
    final result = await _sendRequest('get_messages', {'sessionId': sessionId});
    if (result is List) {
      return result
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<void> sendMessage(String sessionId, String message) async {
    if (_currentState != BridgeConnectionState.connected) {
      throw StateError('Cannot send message: Bridge is disconnected.');
    }
    await _sendRequest('send_message', {
      'sessionId': sessionId,
      'content': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> approve(String approvalId) async {
    await _sendRequest('approval_decision', {
      'approvalId': approvalId,
      'decision': 'approved',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> reject(String approvalId) async {
    await _sendRequest('approval_decision', {
      'approvalId': approvalId,
      'decision': 'rejected',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<ApprovalRequest>> getPendingApprovals() async {
    if (_currentState != BridgeConnectionState.connected) {
      return [];
    }
    final result = await _sendRequest('get_approvals', {});
    if (result is List) {
      return result
          .map((item) => ApprovalRequest.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<dynamic> _sendRequest(String action, Map<String, dynamic> payload) {
    final id = 'req_${++_reqId}';
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    final msg = {
      'type': 'request',
      'action': action,
      'requestId': id,
      'payload': payload,
    };

    _channel?.sink.add(jsonEncode(msg));

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Request $action timed out.');
      },
    );
  }
}
