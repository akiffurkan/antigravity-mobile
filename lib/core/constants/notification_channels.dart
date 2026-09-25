/// Notification channel identifiers and action IDs for Android.
class NotificationChannels {
  NotificationChannels._();

  // Channel IDs
  static const String approvalsChannelId = 'antigravity_approvals';
  static const String approvalsChannelName = 'Antigravity Approvals';
  static const String approvalsChannelDescription =
      'High-priority notifications for command and permission approvals.';

  static const String activityChannelId = 'antigravity_activity';
  static const String activityChannelName = 'Antigravity Activity';
  static const String activityChannelDescription =
      'General session updates, chat events, and companion status notifications.';

  static const String securityChannelId = 'antigravity_security';
  static const String securityChannelName = 'Antigravity Security Alerts';
  static const String securityChannelDescription =
      'Automated security analysis and policy violation notifications.';

  // Action Button IDs
  static const String actionApprove = 'ACTION_APPROVE';
  static const String actionReject = 'ACTION_REJECT';
  static const String actionDetails = 'ACTION_DETAILS';
}
