import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/security_validator.dart';
import '../../../models/approval_request.dart';
import '../../../models/audit_log.dart';
import '../../../models/risk_level.dart';
import '../../../services/bridge/antigravity_bridge.dart';
import '../../../services/bridge/bridge_provider.dart';
import '../../settings/data/settings_providers.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final securityValidatorProvider = Provider<SecurityValidator>((ref) {
  return SecurityValidator();
});

final auditLogsProvider =
    StateNotifierProvider<AuditLogsNotifier, List<AuditLog>>((ref) {
  return AuditLogsNotifier();
});

class AuditLogsNotifier extends StateNotifier<List<AuditLog>> {
  AuditLogsNotifier() : super([]);

  void addLog(AuditLog log) {
    state = [log, ...state];
  }

  void clear() {
    state = [];
  }
}

class ApprovalsNotifier extends StateNotifier<List<ApprovalRequest>> {
  final Ref _ref;
  StreamSubscription<ApprovalRequest>? _approvalSub;
  StreamSubscription<BridgeConnectionState>? _connectionSub;

  ApprovalsNotifier(this._ref) : super([]) {
    _init();
  }

  void _init() {
    final bridge = _ref.read(bridgeProvider);

    _approvalSub = bridge.approvalRequests.listen((incoming) {
      _handleIncomingApproval(incoming);
    });

    // Listen to connection state and fetch pending approvals on connect
    _connectionSub = bridge.connectionState.listen((connState) {
      if (connState == BridgeConnectionState.connected) {
        _fetchPendingApprovals();
      }
    });
  }

  Future<void> _fetchPendingApprovals() async {
    try {
      final bridge = _ref.read(bridgeProvider);
      final approvals = await bridge.getPendingApprovals();
      for (final approval in approvals) {
        _handleIncomingApproval(approval);
      }
    } catch (e) {
      debugPrint('Failed to fetch pending approvals: $e');
    }
  }

  void _handleIncomingApproval(ApprovalRequest request) {
    // Check if request already exists in state
    final exists = state.any((a) => a.id == request.id);
    if (!exists) {
      state = [request, ...state];
      _processApprovalSecurity(request);
    } else {
      // Update existing request status
      state = state.map((a) => a.id == request.id ? request : a).toList();
    }
  }

  Future<void> _processApprovalSecurity(ApprovalRequest request) async {
    final policyEngine = _ref.read(deterministicPolicyEngineProvider);
    final notifier = _ref.read(notificationServiceProvider);
    final aiSettings = _ref.read(aiSettingsProvider);

    // 1. Deterministic policy evaluation
    final policyResult = policyEngine.evaluate(request);

    if (policyResult.calculatedRisk == RiskLevel.critical) {
      debugPrint('Deterministic rule flagged CRITICAL command: ${request.command}');
    }

    if (policyResult.allowsAutoApproval &&
        aiSettings.isAutoApprovalEnabled &&
        request.riskLevel == RiskLevel.low) {
      debugPrint('Auto-approving safe low-risk command: ${request.command}');
      await approve(
        request.id,
        reason: 'Auto-approved by policy engine (${policyResult.reasoning})',
        isAutoApproved: true,
      );
      return;
    }

    // 2. Trigger Heads-Up Notification for human review
    try {
      await notifier.showApprovalNotification(request);
    } catch (e) {
      debugPrint('Notification dispatch warning: $e');
    }
  }

  Future<bool> approve(
    String id, {
    String? reason,
    bool biometricConfirmed = false,
    bool isAutoApproved = false,
  }) async {
    try {
      final bridge = _ref.read(bridgeProvider);
      await bridge.approve(id);

      state = state.map((a) {
        if (a.id == id) {
          return a.copyWith(status: ApprovalStatus.approved);
        }
        return a;
      }).toList();

      _recordAudit(
        id,
        isAutoApproved ? DecisionType.autoApproved : DecisionType.userApproved,
        reason ?? 'Approved by operator',
      );
      return true;
    } catch (e) {
      debugPrint('Approve error: $e');
      return false;
    }
  }

  Future<bool> reject(String id, {String? reason}) async {
    try {
      final bridge = _ref.read(bridgeProvider);
      await bridge.reject(id);

      state = state.map((a) {
        if (a.id == id) {
          return a.copyWith(status: ApprovalStatus.rejected);
        }
        return a;
      }).toList();

      _recordAudit(
        id,
        DecisionType.userRejected,
        reason ?? 'Rejected by operator',
      );
      return true;
    } catch (e) {
      debugPrint('Reject error: $e');
      return false;
    }
  }

  void _recordAudit(String approvalId, DecisionType decision, String reason) {
    final matches = state.where((a) => a.id == approvalId);
    final request = matches.isNotEmpty ? matches.first : null;

    final aiSettings = _ref.read(aiSettingsProvider);

    _ref.read(auditLogsProvider.notifier).addLog(
          AuditLog(
            id: 'aud-${DateTime.now().millisecondsSinceEpoch}',
            timestamp: DateTime.now(),
            approvalRequestId: approvalId,
            projectName: request?.projectName ?? 'Antigravity Workspace',
            command: request?.command ?? 'Terminal Command',
            decision: decision,
            riskLevel: request?.riskLevel ?? RiskLevel.medium,
            reason: reason,
            aiProvider: aiSettings.providerType.displayName,
            aiModel: aiSettings.model,
            user: decision == DecisionType.autoApproved
                ? 'Antigravity AI Engine'
                : 'Mobile User',
          ),
        );
  }

  @override
  void dispose() {
    _approvalSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }
}

final approvalsProvider =
    StateNotifierProvider<ApprovalsNotifier, List<ApprovalRequest>>((ref) {
  return ApprovalsNotifier(ref);
});

final pendingApprovalsProvider = Provider<List<ApprovalRequest>>((ref) {
  final list = ref.watch(approvalsProvider);
  return list.where((a) => a.isPending).toList();
});

final pendingApprovalsCountProvider = Provider<int>((ref) {
  return ref.watch(pendingApprovalsProvider).length;
});

final approvalHistoryProvider = Provider<List<ApprovalRequest>>((ref) {
  final list = ref.watch(approvalsProvider);
  return list.where((a) => !a.isPending).toList();
});
