import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/antigravity_empty_state.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/theme/glowing_badge.dart';
import '../../../models/connection_state.dart';
import '../../../models/device_info.dart';
import '../../../models/session.dart';
import '../../../services/bridge/antigravity_bridge.dart';
import '../../../services/bridge/bridge_provider.dart';
import '../../approvals/data/approval_providers.dart';
import '../../chats/data/chat_providers.dart';
import '../../settings/data/settings_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairedDevice = ref.watch(pairedDeviceProvider);
    final connectionStateAsync = ref.watch(connectionStateStreamProvider);
    final bridge = ref.watch(bridgeProvider);
    final connState = connectionStateAsync.value ?? bridge.currentConnectionState;

    final activeTransport = ref.watch(activeTransportProvider).value ?? ConnectionTransportType.wifi;
    final connectionMode = ref.watch(connectionModeProvider);
    final connStatus = ref.watch(connectionStatusProvider).value ?? ConnectionStatus.offline;

    final pendingCount = ref.watch(pendingApprovalsCountProvider);
    final pendingList = ref.watch(pendingApprovalsProvider);
    final List<Session> sessions = ref.watch(sessionsProvider);
    final aiSettings = ref.watch(aiSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Row(
              children: [
                const AntigravityLogo(
                  size: LogoSize.small,
                  showText: false,
                  animate: false,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANTIGRAVITY',
                      style: AppTypography.titleSmall.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'MOBILE CONTROL CENTER',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.hub_outlined),
                tooltip: 'Connection Hub',
                onPressed: () => context.push('/connection-hub'),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Pair Device',
                onPressed: () => context.push('/pairing'),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Connected PC Status Glass Card
                _buildPcStatusCard(
                  context,
                  ref,
                  pairedDevice,
                  connState,
                  activeTransport,
                  connectionMode,
                  connStatus,
                ),
                const SizedBox(height: 16),

                // 2. Pending Approvals Banner
                if (pendingCount > 0) ...[
                  _buildPendingApprovalsAlert(context, ref, pendingCount, pendingList.first),
                  const SizedBox(height: 16),
                ],

                // 3. AI Security Status Card
                _buildSecurityStatusCard(context, aiSettings),
                const SizedBox(height: 20),

                // 4. Active PC Sessions Header & List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVE SESSIONS',
                      style: AppTypography.titleSmall.copyWith(
                        fontSize: 13,
                        letterSpacing: 1.1,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '${sessions.length} ACTIVE',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (sessions.isEmpty)
                  const AntigravityEmptyState(
                    title: 'No Active Sessions',
                    message: 'Sessions opened in Antigravity on your PC will automatically synchronize here.',
                    logoSize: LogoSize.small,
                  )
                else
                  ...sessions.map((sess) => _buildSessionItem(context, ref, sess)),

                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPcStatusCard(
    BuildContext context,
    WidgetRef ref,
    DeviceInfo? pairedDevice,
    BridgeConnectionState connState,
    ConnectionTransportType activeTransport,
    ConnectionMode connectionMode,
    ConnectionStatus connStatus,
  ) {
    Color stateColor;
    String stateLabel;
    IconData stateIcon;
    final isConnected = connState == BridgeConnectionState.connected;

    if (pairedDevice == null) {
      stateColor = AppColors.textMuted;
      stateLabel = 'No PC Paired';
      stateIcon = Icons.link_off_rounded;
    } else {
      switch (connState) {
        case BridgeConnectionState.connected:
          stateColor = AppColors.success;
          stateLabel = 'ONLINE';
          stateIcon = activeTransport == ConnectionTransportType.bluetooth
              ? Icons.bluetooth_connected_rounded
              : Icons.wifi_tethering_rounded;
          break;
        case BridgeConnectionState.connecting:
          stateColor = AppColors.warning;
          stateLabel = 'CONNECTING...';
          stateIcon = Icons.sync_rounded;
          break;
        case BridgeConnectionState.reconnecting:
          stateColor = AppColors.warning;
          stateLabel = 'RECONNECTING...';
          stateIcon = Icons.autorenew_rounded;
          break;
        case BridgeConnectionState.disconnected:
          stateColor = AppColors.danger;
          stateLabel = 'OFFLINE';
          stateIcon = Icons.wifi_off_rounded;
          break;
      }
    }

    final isBluetooth = activeTransport == ConnectionTransportType.bluetooth;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: isConnected ? AppColors.primary.withOpacity(0.35) : AppColors.cardBorder,
      fillColor: AppColors.cardBackground,
      onTap: () => context.push('/connection-hub'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: stateColor.withOpacity(0.3), width: 1),
                ),
                child: Icon(
                  isBluetooth ? Icons.bluetooth_rounded : Icons.computer_rounded,
                  color: stateColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pairedDevice?.name ?? 'Antigravity Companion PC',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: stateColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: stateColor.withOpacity(0.9),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          stateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: stateColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(width: 8),
                        Text(
                          isBluetooth ? 'Bluetooth Link' : 'WebSocket 9400',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isConnected && pairedDevice != null)
                TextButton.icon(
                  onPressed: () async {
                    final bridge = ref.read(bridgeProvider);
                    await bridge.connect();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                  label: Text('Retry', style: AppTypography.codeSmall.copyWith(color: AppColors.primary)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: AppColors.primaryGlow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                GlowingBadge(
                  label: isBluetooth ? 'BLUETOOTH' : 'WI-FI LAN',
                  color: isBluetooth ? AppColors.secondary : AppColors.primary,
                  icon: stateIcon,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  isBluetooth ? Icons.bluetooth_audio_rounded : Icons.lan_rounded,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pairedDevice == null
                        ? 'No PC paired. Tap to auto-discover on Wi-Fi.'
                        : (isBluetooth
                            ? (pairedDevice.bluetoothName ?? pairedDevice.bluetoothAddress ?? 'Paired BT Host')
                            : '${pairedDevice.ipAddress}:${pairedDevice.port} (Port 9400 Active)'),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hub',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsAlert(
    BuildContext context,
    WidgetRef ref,
    int count,
    dynamic topRequest,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.warning.withOpacity(0.5),
      fillColor: AppColors.warning.withOpacity(0.08),
      onTap: () => context.push('/approvals'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Approval Required',
                  style: AppTypography.titleSmall.copyWith(color: AppColors.warning),
                ),
                const SizedBox(height: 2),
                Text(
                  topRequest.command,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.codeSmall.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildSecurityStatusCard(BuildContext context, dynamic aiSettings) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deterministic Security Policy',
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  aiSettings.isAutoApprovalEnabled
                      ? 'AI Auto-Approval: Active (Safe Commands Only)'
                      : 'Strict Manual Confirmation: Enforced',
                  style: AppTypography.bodySmall.copyWith(
                    color: aiSettings.isAutoApprovalEnabled
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GlowingBadge(
            label: 'ARMED',
            color: AppColors.success,
            showDot: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, WidgetRef ref, Session session) {
    final hasPending = session.pendingApprovalCount > 0;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      onTap: () {
        ref.read(activeSessionIdProvider.notifier).state = session.id;
        context.push('/chats');
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasPending
                  ? AppColors.warning.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasPending ? Icons.pending_actions_rounded : Icons.terminal_rounded,
              color: hasPending ? AppColors.warning : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title, style: AppTypography.titleSmall),
                const SizedBox(height: 4),
                Text(
                  session.lastMessagePreview ?? session.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          if (hasPending)
            GlowingBadge(
              label: '${session.pendingApprovalCount} PENDING',
              color: AppColors.warning,
            )
          else
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
