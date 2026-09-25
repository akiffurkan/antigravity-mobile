import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/approval_request.dart';
import '../constants/notification_channels.dart';

/// Notification Service for displaying heads-up and interactive Android notifications.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux;
  }

  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onNotificationResponse,
    DidReceiveNotificationResponseCallback? onBackgroundNotificationResponse,
  }) async {
    if (!isSupportedPlatform) {
      debugPrint('NotificationService: Local notifications not supported on ${kIsWeb ? 'Web' : Platform.operatingSystem}.');
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
      );

      await _createNotificationChannels();
    } catch (e) {
      debugPrint('NotificationService initialization caught safely: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // 1. Approvals Channel (High Importance, Sound, Vibration, Heads-up)
      const approvalsChannel = AndroidNotificationChannel(
        NotificationChannels.approvalsChannelId,
        NotificationChannels.approvalsChannelName,
        description: NotificationChannels.approvalsChannelDescription,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      // 2. Activity Channel (Default Importance)
      const activityChannel = AndroidNotificationChannel(
        NotificationChannels.activityChannelId,
        NotificationChannels.activityChannelName,
        description: NotificationChannels.activityChannelDescription,
        importance: Importance.defaultImportance,
      );

      // 3. Security Channel (High Importance)
      const securityChannel = AndroidNotificationChannel(
        NotificationChannels.securityChannelId,
        NotificationChannels.securityChannelName,
        description: NotificationChannels.securityChannelDescription,
        importance: Importance.high,
      );

      await androidImplementation.createNotificationChannel(approvalsChannel);
      await androidImplementation.createNotificationChannel(activityChannel);
      await androidImplementation.createNotificationChannel(securityChannel);
    }
  }

  Future<void> requestPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> showApprovalNotification(ApprovalRequest request) async {
    if (!isSupportedPlatform) return;

    try {
      final notificationId = request.id.hashCode;

      final androidDetails = AndroidNotificationDetails(
        NotificationChannels.approvalsChannelId,
        NotificationChannels.approvalsChannelName,
        channelDescription: NotificationChannels.approvalsChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        color: const Color(0xFF00D2FF),
        ledColor: const Color(0xFF00D2FF),
        ledOnMs: 1000,
        ledOffMs: 500,
        enableLights: true,
        category: AndroidNotificationCategory.status,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            NotificationChannels.actionApprove,
            '✓ Kabul Et',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            NotificationChannels.actionReject,
            '✕ Reddet',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            NotificationChannels.actionDetails,
            '📱 Detayları Gör',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
        styleInformation: BigTextStyleInformation(
          '${request.command}\n\n'
          '${request.riskLevel.label} • ${request.projectName}\n'
          '${request.description}',
          contentTitle: 'Antigravity • Permission Required',
          summaryText: 'Waiting for your approval',
        ),
      );

      final details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: notificationId,
        title: 'Antigravity: Permission Required',
        body: '${request.command} (${request.riskLevel.label})',
        notificationDetails: details,
        payload: jsonEncode({
          'approvalId': request.id,
          'sessionId': request.sessionId,
        }),
      );
    } catch (e) {
      debugPrint('Error showing approval notification: $e');
    }
  }

  Future<void> cancelApprovalNotification(String approvalId) async {
    if (!isSupportedPlatform) return;
    try {
      await _notificationsPlugin.cancel(id: approvalId.hashCode);
    } catch (e) {
      debugPrint('Error canceling notification: $e');
    }
  }
}
