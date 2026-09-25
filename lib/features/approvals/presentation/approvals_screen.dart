import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/antigravity_empty_state.dart';
import '../../../core/theme/code_snippet_view.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/theme/glowing_badge.dart';
import '../../../models/approval_request.dart';
import '../../../models/audit_log.dart';
import '../../../models/risk_level.dart';
import '../data/approval_providers.dart';
import '../../settings/data/settings_providers.dart';

class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _historyFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingApprovalsCountProvider);
    final pendingList = ref.watch(pendingApprovalsProvider);
    final historyList = ref.watch(approvalHistoryProvider);
    final auditLogs = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Permissions & Approvals', style: AppTypography.titleMedium),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: AppTypography.titleSmall.copyWith(fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'History'),
            const Tab(text: 'Audit Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Pending Approvals Tab
          _buildPendingTab(context, pendingList),

          // 2. History Tab
          _buildHistoryTab(context, historyList),

          // 3. Audit Log Tab
          _buildAuditLogTab(context, auditLogs),
        ],
      ),
    );
  }

  Widget _buildPendingTab(BuildContext context, List<ApprovalRequest> list) {
    if (list.isEmpty) {
      return const AntigravityEmptyState(
        title: 'No Pending Approvals',
        message: 'All command execution requests from Antigravity are clear.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final request = list[index];
        return _buildPendingCard(context, request);
      },
    );
  }

  Widget _buildPendingCard(BuildContext context, ApprovalRequest request) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderColor: request.riskLevel.color.withOpacity(0.4),
      onTap: () => context.push('/approval-detail/${request.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(request.projectName, style: AppTypography.titleSmall),
              GlowingBadge(
                label: request.riskLevel.label,
                color: request.riskLevel.color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          CodeSnippetView(
            code: request.command,
            language: 'bash',
            showCopyButton: false,
          ),
          const SizedBox(height: 10),
          Text(
            request.description,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(approvalsProvider.notifier).reject(request.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permission request rejected.')),
                    );
                  },
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                  label: Text('Reddet', style: AppTypography.bodySmall.copyWith(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (request.requiresBiometric) {
                      final biometricService = ref.read(biometricServiceProvider);
                      final authed = await biometricService.authenticate(
                        reason: 'Biometric verification required to approve high risk command.',
                      );
                      if (!authed) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Biometric authentication failed.')),
                        );
                        return;
                      }
                    }

                    await ref.read(approvalsProvider.notifier).approve(
                          request.id,
                          biometricConfirmed: request.requiresBiometric,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permission request approved!')),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.black),
                  label: Text(
                    'Kabul Et',
                    style: AppTypography.titleSmall.copyWith(color: Colors.black, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, List<ApprovalRequest> history) {
    final filtered = history.where((item) {
      if (_historyFilter == 'All') return true;
      if (_historyFilter == 'Approved') {
        return item.status == ApprovalStatus.approved ||
            item.status == ApprovalStatus.autoApproved;
      }
      if (_historyFilter == 'Rejected') return item.status == ApprovalStatus.rejected;
      if (_historyFilter == 'Auto') return item.status == ApprovalStatus.autoApproved;
      if (_historyFilter == 'High Risk') {
        return item.riskLevel == RiskLevel.high || item.riskLevel == RiskLevel.critical;
      }
      return true;
    }).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: ['All', 'Approved', 'Rejected', 'Auto', 'High Risk'].map((filter) {
              final isSelected = _historyFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.25),
                  backgroundColor: AppColors.glassFill,
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _historyFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const AntigravityEmptyState(
                  title: 'No Records Found',
                  message: 'No approval actions match the current filter.',
                  logoSize: LogoSize.small,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isApproved = item.status == ApprovalStatus.approved ||
                        item.status == ApprovalStatus.autoApproved;
                    final statusColor =
                        isApproved ? AppColors.success : AppColors.danger;

                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isApproved ? Icons.check_circle : Icons.cancel,
                              color: statusColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.command,
                                    style: AppTypography.codeSmall.copyWith(
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.status.label} • ${item.projectName}',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          GlowingBadge(
                            label: item.riskLevel.name.toUpperCase(),
                            color: item.riskLevel.color,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAuditLogTab(BuildContext context, List<AuditLog> logs) {
    if (logs.isEmpty) {
      return const AntigravityEmptyState(
        title: 'Audit Log Empty',
        message: 'No security events or authorization decisions recorded yet.',
        logoSize: LogoSize.small,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp);

        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(timeStr, style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted)),
                  GlowingBadge(
                    label: log.decision.label,
                    color: log.decision == DecisionType.userApproved ||
                            log.decision == DecisionType.autoApproved
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Command: ${log.command}',
                style: AppTypography.codeSmall.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text('Reason: ${log.reason}', style: AppTypography.bodySmall),
              const SizedBox(height: 4),
              Text(
                'Author: ${log.user} | Model: ${log.aiModel ?? 'N/A'}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
