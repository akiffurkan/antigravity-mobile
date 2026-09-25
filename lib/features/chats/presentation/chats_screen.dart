import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/antigravity_empty_state.dart';
import '../../../core/theme/code_snippet_view.dart';
import '../../../core/theme/glass_card.dart';
import '../../../models/chat_message.dart';
import '../../../models/session.dart';
import '../data/chat_providers.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final activeSession = ref.read(activeSessionProvider);
    if (activeSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to Antigravity PC or start a session first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    ref.read(chatMessagesProvider.notifier).sendMessage(text);
    _textController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Session> sessions = ref.watch(sessionsProvider);
    final activeSession = ref.watch(activeSessionProvider);
    final messages = ref.watch(chatMessagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeSession?.title ?? 'Antigravity Chat',
              style: AppTypography.titleSmall,
            ),
            Text(
              activeSession?.projectName ?? 'Remote Session',
              style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch Session',
            color: AppColors.surfaceElevated,
            onSelected: (id) {
              ref.read(activeSessionIdProvider.notifier).state = id;
            },
            itemBuilder: (context) {
              return sessions.map<PopupMenuEntry<String>>((Session s) {
                return PopupMenuItem<String>(
                  value: s.id,
                  child: Row(
                    children: [
                      Icon(
                        s.id == activeSession?.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: s.id == activeSession?.id
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: s.id == activeSession?.id
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Message stream list
          Expanded(
            child: messages.isEmpty
                ? const AntigravityEmptyState(
                    title: 'No Conversations',
                    message: 'Send a prompt or select a session to begin interacting with Antigravity on your PC.',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageItem(context, msg);
                    },
                  ),
          ),

          // Message Composer Input Bar
          _buildComposer(context),
        ],
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, ChatMessage msg) {
    final isUser = msg.role == MessageRole.user;
    final timeStr = DateFormat('HH:mm').format(msg.timestamp);

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.18),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg.content,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: AppTypography.bodySmall.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    // Antigravity or Tool message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                ),
                const SizedBox(width: 6),
                Text(
                  msg.role == MessageRole.tool ? 'Tool: ${msg.toolName ?? 'runner'}' : 'Antigravity',
                  style: AppTypography.codeSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(timeStr, style: AppTypography.bodySmall.copyWith(fontSize: 10)),
              ],
            ),
            const SizedBox(height: 6),
            GlassCard(
              padding: const EdgeInsets.all(14),
              fillColor: AppColors.glassFill,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.content.isNotEmpty)
                    Text(
                      msg.content,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                  if (msg.codeSnippet != null) ...[
                    const SizedBox(height: 8),
                    CodeSnippetView(
                      code: msg.codeSnippet!,
                      language: msg.language ?? 'bash',
                    ),
                  ],
                  if (msg.approvalRequestId != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/approvals'),
                      icon: const Icon(Icons.shield_outlined, size: 16, color: AppColors.warning),
                      label: Text(
                        'Review Approval Request',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        border: const Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _textController,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Prompt Antigravity PC...',
                  hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
