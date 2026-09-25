import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/approval_request.dart';
import '../../models/audit_log.dart';
import '../../models/device_info.dart';
import '../../models/risk_level.dart';
import '../../services/bridge/antigravity_bridge.dart';
import '../constants/notification_channels.dart';
import '../security/security_validator.dart';

typedef OnNavigateToDetails = void Function(String approvalId);
typedef OnAuditLogged = void Function(AuditLog log);

class NotificationActionHandler {
  final SecurityValidator validator;
  final AntigravityBridge bridge;
  final OnNavigateToDetails? onNavigateToDetails;
  final OnAuditLogged? onAuditLogged;

  NotificationActionHandler({
    required this.validator,
    required this.bridge,
    this.onNavigateToDetails,
    this.onAuditLogged,
  });

  Future<void> handleResponse(
    NotificationResponse response, {
    required ApprovalRequest? Function(String id) getRequestById,
    required DeviceInfo? Function() getPairedDevice,
    required String? Function() getAuthToken,
  }) async {
    final actionId = response.actionId;
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final approvalId = data['approvalId'] as String?;
      if (approvalId == null) return;

      if (actionId == NotificationChannels.actionDetails || actionId == null) {
        // Navigate user to detail screen
        onNavigateToDetails?.call(approvalId);
        return;
      }

      final request = getRequestById(approvalId);
      final pairedDevice = getPairedDevice();
      final authToken = getAuthToken();

      if (actionId == NotificationChannels.actionApprove) {
        // Validate request prior to execution
        final validation = validator.validateApprovalAction(
          request: request,
          pairedDevice: pairedDevice,
          authToken: authToken,
          biometricPassed: false, // Notification action cannot bypass biometric
        );

        if (!validation.isValid) {
          debugPrint('Notification approval rejected by security validator: ${validation.message}');
          onAuditLogged?.call(AuditLog(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            approvalRequestId: approvalId,
            projectName: request?.projectName ?? 'Unknown',
            command: request?.command ?? '',
            decision: DecisionType.policyBlocked,
            riskLevel: request?.riskLevel ?? RiskLevel.medium,
            reason: 'Security Validation Failed: ${validation.message}',
            user: 'Notification Background Handler',
          ));
          return;
        }

        // Action approved! Forward to Antigravity Bridge
        await bridge.approve(approvalId);

        onAuditLogged?.call(AuditLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          approvalRequestId: approvalId,
          projectName: request!.projectName,
          command: request.command,
          decision: DecisionType.userApproved,
          riskLevel: request.riskLevel,
          reason: 'Approved via Samsung/Android Interactive Notification Action',
          user: 'Notification Handler',
        ));
      } else if (actionId == NotificationChannels.actionReject) {
        // Forward rejection to Antigravity Bridge
        await bridge.reject(approvalId);

        onAuditLogged?.call(AuditLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          approvalRequestId: approvalId,
          projectName: request?.projectName ?? 'Unknown',
          command: request?.command ?? '',
          decision: DecisionType.userRejected,
          riskLevel: request?.riskLevel ?? RiskLevel.medium,
          reason: 'Rejected via Interactive Notification Action',
          user: 'Notification Handler',
        ));
      }
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }
}
