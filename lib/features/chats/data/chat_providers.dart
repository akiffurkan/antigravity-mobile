import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/chat_message.dart';
import '../../../models/session.dart';
import '../../../services/bridge/antigravity_bridge.dart';
import '../../../services/bridge/bridge_provider.dart';

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, List<Session>>((ref) {
  return SessionsNotifier(ref);
});

class SessionsNotifier extends StateNotifier<List<Session>> {
  final Ref _ref;
  StreamSubscription? _connectionSub;

  SessionsNotifier(this._ref) : super([]) {
    // Listen to connection state changes and refresh sessions when connected
    _connectionSub =
        _ref.read(bridgeProvider).connectionState.listen((connState) {
      if (connState == BridgeConnectionState.connected) {
        refreshSessions();
      }
    });
  }

  Future<void> refreshSessions() async {
    try {
      final bridge = _ref.read(bridgeProvider);
      final sessions = await bridge.getSessions();
      state = sessions;

      // Auto-select first session if none is selected
      if (sessions.isNotEmpty) {
        final currentActive = _ref.read(activeSessionIdProvider);
        if (currentActive == null) {
          _ref.read(activeSessionIdProvider.notifier).state = sessions.first.id;
        }
      }
    } catch (_) {
      state = [];
    }
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    super.dispose();
  }
}

final activeSessionIdProvider = StateProvider<String?>((ref) => null);

final activeSessionProvider = Provider<Session?>((ref) {
  final activeId = ref.watch(activeSessionIdProvider);
  if (activeId == null) return null;
  final sessions = ref.watch(sessionsProvider);
  try {
    return sessions.firstWhere((s) => s.id == activeId);
  } catch (_) {
    return null;
  }
});

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  final activeId = ref.watch(activeSessionIdProvider);
  return ChatMessagesNotifier(ref, activeId);
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  final String? sessionId;
  StreamSubscription? _messageSub;

  ChatMessagesNotifier(this._ref, this.sessionId) : super([]) {
    if (sessionId != null && sessionId!.isNotEmpty) {
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    if (sessionId == null) return;
    try {
      final bridge = _ref.read(bridgeProvider);
      final msgs = await bridge.getMessages(sessionId!);
      state = msgs;

      _messageSub?.cancel();
      _messageSub = bridge.messageStream.listen((incoming) {
        if (incoming.sessionId == sessionId) {
          state = [...state, incoming];
        }
      });
    } catch (_) {
      state = [];
    }
  }

  Future<void> sendMessage(String text) async {
    if (sessionId == null || text.trim().isEmpty) return;
    final bridge = _ref.read(bridgeProvider);
    await bridge.sendMessage(sessionId!, text.trim());
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }
}
