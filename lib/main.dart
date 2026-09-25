import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/navigation/app_router.dart';
import 'core/notifications/notification_action_handler.dart';
import 'features/approvals/data/approval_providers.dart';
import 'services/bridge/bridge_provider.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Notification background action received: ${notificationResponse.actionId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Run App IMMEDIATELY so the view hierarchy mounts without delay
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AntigravityMobileApp(),
    ),
  );

  // Initialize background services asynchronously (notifications, bridge connection)
  _initializeBackgroundServices(container);
}

Future<void> _initializeBackgroundServices(ProviderContainer container) async {
  try {
    final notificationService = container.read(notificationServiceProvider);
    final bridge = container.read(bridgeProvider);
    final validator = container.read(securityValidatorProvider);

    final actionHandler = NotificationActionHandler(
      validator: validator,
      bridge: bridge,
      onNavigateToDetails: (approvalId) {
        container.read(routerProvider).push('/approval-detail/$approvalId');
      },
      onAuditLogged: (log) {
        container.read(auditLogsProvider.notifier).addLog(log);
      },
    );

    await notificationService.initialize(
      onNotificationResponse: (NotificationResponse response) async {
        await actionHandler.handleResponse(
          response,
          getRequestById: (id) {
            final list = container.read(approvalsProvider);
            try {
              return list.firstWhere((a) => a.id == id);
            } catch (_) {
              return null;
            }
          },
          getPairedDevice: () => container.read(pairedDeviceProvider),
          getAuthToken: () => container.read(pairedDeviceProvider)?.authToken,
        );
      },
      onBackgroundNotificationResponse: notificationTapBackground,
    );
  } catch (e) {
    debugPrint('Background notification service initialization handled: $e');
  }

  try {
    final bridge = container.read(bridgeProvider);
    await bridge.connect();
  } catch (e) {
    debugPrint('Initial bridge connection handled: $e');
  }
}
