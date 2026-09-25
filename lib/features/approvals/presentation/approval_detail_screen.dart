import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/deterministic_policy_engine.dart';
import '../../../core/theme/code_snippet_view.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/theme/glowing_badge.dart';
import '../../../models/approval_request.dart';
import '../../../models/risk_level.dart';
import '../data/approval_providers.dart';
import '../../settings/data/settings_providers.dart';

class ApprovalDetailScreen extends ConsumerStatefulWidget {
  final String approvalId;

  const ApprovalDetailScreen({super.key, required this.approvalId});

  @override
  ConsumerState<ApprovalDetailScreen> createState() =>
      _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends ConsumerState<ApprovalDetailScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final allApprovals = ref.watch(approvalsProvider);
    final request = allApprovals.firstWhere(
      (a) => a.id == widget.approvalId,
      orElse: () => ApprovalRequest(
        id: widget.approvalId,
        timestamp: DateTime.now(),
        sessionId: '',
        projectId: '',
        projectName: 'Not Found',
        command: '',
        description: 'Request has been expired or removed.',
        requestedAction: '',
        riskLevel: RiskLevel.low,
        status: ApprovalStatus.expired,
        expiresAt: DateTime.now(),
        nonce: '',
      ),
    );

    final policies = ref.watch(securityPoliciesProvider);
    final policyEngine = DeterministicPolicyEngine(policies: policies);
    final policyResult = policyEngine.evaluate(request);

    final isPending = request.isPending;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Permission Request', style: AppTypography.titleMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audit link copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project & Source Meta Card
            GlassCard(
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
                      Icons.folder_special_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PROJECT', style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
                        Text(request.projectName, style: AppTypography.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Source: ${request.source}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  GlowingBadge(
                    label: request.status.label,
                    color: request.isPending
                        ? AppColors.warning
                        : (request.status == ApprovalStatus.approved ||
                                request.status == ApprovalStatus.autoApproved
                            ? AppColors.success
                            : AppColors.danger),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Command Card
            Text('COMMAND', style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 6),
            CodeSnippetView(
              code: request.command,
              language: 'bash',
            ),
            const SizedBox(height: 16),

            // Risk Assessment Card
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: request.riskLevel.color.withOpacity(0.3),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: request.riskLevel.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: request.riskLevel.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RISK ASSESSMENT', style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
                        Text(request.riskLevel.label, style: AppTypography.titleMedium.copyWith(color: request.riskLevel.color)),
                      ],
                    ),
                  ),
                  if (request.requiresBiometric)
                    GlowingBadge(
                      label: 'BIOMETRIC REQ',
                      color: AppColors.danger,
                      icon: Icons.fingerprint_rounded,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AI Security Analysis Card
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_alt_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('AI SECURITY ANALYSIS', style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
                      const Spacer(),
                      if (request.aiConfidence != null)
                        Text(
                          '${(request.aiConfidence! * 100).toInt()}% CONFIDENCE',
                          style: AppTypography.codeSmall.copyWith(color: AppColors.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    request.aiReason ??
                        'AI model evaluated the command syntax, execution surface, and requested privileges.',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Deterministic Policy Evaluation Card
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rule_folder_rounded, size: 20, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('DETERMINISTIC POLICY CHECK',
                          style: AppTypography.titleSmall.copyWith(color: AppColors.secondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(policyResult.reasoning, style: AppTypography.bodyMedium),
                  if (policyResult.blockedByRule != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Enforced Rule: ${policyResult.blockedByRule}',
                        style: AppTypography.codeSmall.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handleReject,
                      icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                      label: Text('Reddet', style: AppTypography.titleSmall.copyWith(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleApprove(request),
                      icon: const Icon(Icons.check_rounded, color: Colors.black),
                      label: Text('Kabul Et', style: AppTypography.titleSmall.copyWith(color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(ApprovalRequest request) async {
    setState(() => _isProcessing = true);
    try {
      if (request.requiresBiometric) {
        final biometricService = ref.read(biometricServiceProvider);
        final authenticated = await biometricService.authenticate(
          reason: 'Biometric authorization required to execute ${request.command}',
        );

        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric verification failed.')),
            );
          }
          return;
        }
      }

      final success = await ref.read(approvalsProvider.notifier).approve(
            widget.approvalId,
            biometricConfirmed: request.requiresBiometric,
          );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Approval executed successfully.')),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Approval validation rejected.')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(approvalsProvider.notifier).reject(widget.approvalId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission request rejected.')),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
