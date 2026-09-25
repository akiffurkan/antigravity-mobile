import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/theme/glowing_badge.dart';
import '../../../models/approval_request.dart';
import '../../../models/connection_state.dart';
import '../../../models/risk_level.dart';
import '../../../models/security_decision.dart';
import '../../../services/bridge/bridge_provider.dart';
import '../../ai_security/domain/ai_provider.dart';
import '../../approvals/data/approval_providers.dart';
import '../data/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _isSavingKey = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final aiSettings = ref.read(aiSettingsProvider);
    final storage = ref.read(secureStorageProvider);
    final key = await storage.getApiKey(aiSettings.providerType.name);
    if (key != null) {
      _apiKeyController.text = key;
    }
  }

  Future<void> _saveApiKey() async {
    setState(() => _isSavingKey = true);
    final aiSettings = ref.read(aiSettingsProvider);
    final storage = ref.read(secureStorageProvider);
    await storage.saveApiKey(aiSettings.providerType.name, _apiKeyController.text.trim());
    setState(() => _isSavingKey = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key encrypted and saved to Keystore!')),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairedDevice = ref.watch(pairedDeviceProvider);
    final activeTransport = ref.watch(activeTransportProvider).value ?? ConnectionTransportType.wifi;
    final connectionMode = ref.watch(connectionModeProvider);
    final isBluetooth = activeTransport == ConnectionTransportType.bluetooth;

    final aiSettings = ref.watch(aiSettingsProvider);
    final aiNotifier = ref.read(aiSettingsProvider.notifier);
    final policies = ref.watch(securityPoliciesProvider);
    final policyNotifier = ref.read(securityPoliciesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings & Security', style: AppTypography.titleMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 0. Connection & Hardware Transport
          Text('CONNECTION & HARDWARE TRANSPORT', style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pairedDevice?.name ?? 'Antigravity PC',
                            style: AppTypography.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBluetooth
                                ? (pairedDevice?.bluetoothName ?? pairedDevice?.bluetoothAddress ?? 'Bluetooth Host')
                                : '${pairedDevice?.ipAddress ?? '127.0.0.1'}:${pairedDevice?.port ?? 9400}',
                            style: AppTypography.codeSmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    GlowingBadge(
                      label: isBluetooth ? 'BLUETOOTH' : 'WI-FI',
                      color: isBluetooth ? AppColors.primary : AppColors.secondary,
                      icon: isBluetooth ? Icons.bluetooth_rounded : Icons.wifi_rounded,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text('Transport Mode', style: AppTypography.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ConnectionMode.values.map((mode) {
                    final isSelected = connectionMode == mode;
                    return ChoiceChip(
                      label: Text(mode.label),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withOpacity(0.25),
                      backgroundColor: AppColors.glassFill,
                      labelStyle: AppTypography.bodySmall.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) {
                        ref.read(connectionModeProvider.notifier).state = mode;
                        ref.read(connectionManagerProvider).setMode(mode);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/connection-hub'),
                        icon: const Icon(Icons.hub_rounded, size: 16),
                        label: const Text('Change Connection'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.titanium,
                          side: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(bridgeProvider).disconnect();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Disconnected from Antigravity Bridge.')),
                        );
                      },
                      icon: const Icon(Icons.power_settings_new_rounded, size: 16, color: AppColors.danger),
                      label: Text('Disconnect', style: AppTypography.bodySmall.copyWith(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. AI Security Configuration
          Text('AI SECURITY ENGINE', style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Enable AI Security Analysis', style: AppTypography.titleSmall),
                  subtitle: Text('Analyze commands with AI prior to execution', style: AppTypography.bodySmall),
                  value: aiSettings.isAiAnalysisEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (val) => aiNotifier.setAiAnalysisEnabled(val),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Automatic Approval (Safe Only)', style: AppTypography.titleSmall),
                  subtitle: Text('Auto-approve if Policy permits & AI rates LOW_RISK', style: AppTypography.bodySmall),
                  value: aiSettings.isAutoApprovalEnabled,
                  activeColor: AppColors.success,
                  onChanged: (val) => aiNotifier.setAutoApprovalEnabled(val),
                ),
                const Divider(height: 24),
                Text('AI Provider', style: AppTypography.bodySmall),
                const SizedBox(height: 6),
                DropdownButtonFormField<AIProviderType>(
                  value: aiSettings.providerType,
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: AIProviderType.values.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p.displayName, style: AppTypography.bodyMedium),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      aiNotifier.setProviderType(val);
                      _loadApiKey();
                    }
                  },
                ),
                const SizedBox(height: 14),
                Text('Model', style: AppTypography.bodySmall),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: aiSettings.model,
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: aiSettings.providerType.availableModels.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(m, style: AppTypography.bodyMedium),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) aiNotifier.setModel(val);
                  },
                ),
                const SizedBox(height: 14),
                Text('API Key (Encrypted in Keystore)', style: AppTypography.bodySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        style: AppTypography.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: 'sk-antigravity-...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isSavingKey ? null : _saveApiKey,
                      child: const Text('Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Risk Mode', style: AppTypography.bodySmall),
                const SizedBox(height: 6),
                Row(
                  children: RiskMode.values.map((mode) {
                    final isSel = aiSettings.riskMode == mode;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(mode.label),
                        selected: isSel,
                        selectedColor: AppColors.primary.withOpacity(0.25),
                        backgroundColor: AppColors.glassFill,
                        onSelected: (_) => aiNotifier.setRiskMode(mode),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Deterministic Security Policies (Strict overrides)
          Text('DETERMINISTIC SECURITY POLICIES', style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            'Strict rules that ALWAYS require manual user confirmation regardless of AI judgment:',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildPolicySwitch(
                  title: 'Privileged / sudo commands',
                  value: policies.requireConfirmationForSudo,
                  onChanged: policyNotifier.toggleSudo,
                ),
                const Divider(),
                _buildPolicySwitch(
                  title: 'File & directory deletion (rm, del)',
                  value: policies.requireConfirmationForFileDeletion,
                  onChanged: policyNotifier.toggleDeletion,
                ),
                const Divider(),
                _buildPolicySwitch(
                  title: 'Credentials & keys (.env, id_rsa)',
                  value: policies.requireConfirmationForCredentials,
                  onChanged: policyNotifier.toggleCredentials,
                ),
                const Divider(),
                _buildPolicySwitch(
                  title: 'SSH & Remote Access',
                  value: policies.requireConfirmationForSSH,
                  onChanged: policyNotifier.toggleSSH,
                ),
                const Divider(),
                _buildPolicySwitch(
                  title: 'Piped shell scripts (curl | bash)',
                  value: policies.requireConfirmationForNetworkScripts,
                  onChanged: policyNotifier.toggleNetworkScripts,
                ),
                const Divider(),
                _buildPolicySwitch(
                  title: 'Package installations (npm, pip, pub)',
                  value: policies.requireConfirmationForPackageInstall,
                  onChanged: policyNotifier.togglePackages,
                ),
                const Divider(),
                _buildPolicySwitch(
                  title: 'Unknown or unclassified commands',
                  value: policies.requireConfirmationForUnknownCommands,
                  onChanged: policyNotifier.toggleUnknown,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Biometric Security
          Text('BIOMETRIC CONFIRMATION', style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Require Fingerprint / Face Unlock for approval confirmation:',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 12),
                ...BiometricPolicy.values.map((pol) {
                  return RadioListTile<BiometricPolicy>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(pol.label, style: AppTypography.titleSmall),
                    value: pol,
                    groupValue: aiSettings.biometricPolicy,
                    activeColor: AppColors.primary,
                    onChanged: (v) {
                      if (v != null) aiNotifier.setBiometricPolicy(v);
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Notification Diagnostics
          Text('NOTIFICATION DIAGNOSTICS', style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify system notification delivery and permission channels on this device.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final notifier = ref.read(notificationServiceProvider);
                    await notifier.showApprovalNotification(
                      ApprovalRequest(
                        id: 'test-ping-1',
                        timestamp: DateTime.now(),
                        sessionId: 'diag-session',
                        projectId: 'antigravity-mobile',
                        projectName: 'Antigravity Mobile',
                        command: 'System Notification Test',
                        description: 'Device notification permissions and channels verified successfully.',
                        requestedAction: 'Self Test Diagnostic',
                        riskLevel: RiskLevel.low,
                        status: ApprovalStatus.pending,
                        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
                        nonce: 'test-nonce-diag-1',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test notification dispatched!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: const Text('Send Test System Notification'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPolicySwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
      value: value,
      activeColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}
