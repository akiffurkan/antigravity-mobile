import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class CodeSnippetView extends StatefulWidget {
  final String code;
  final String? language;
  final bool showCopyButton;

  const CodeSnippetView({
    super.key,
    required this.code,
    this.language,
    this.showCopyButton = true,
  });

  @override
  State<CodeSnippetView> createState() => _CodeSnippetViewState();
}

class _CodeSnippetViewState extends State<CodeSnippetView> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Command copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.codeBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.codeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.language != null || widget.showCopyButton)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.codeBorder),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.language?.toUpperCase() ?? 'BASH',
                    style: AppTypography.codeSmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.showCopyButton)
                    InkWell(
                      onTap: _copyToClipboard,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Icon(
                              _copied ? Icons.check : Icons.copy_rounded,
                              size: 13,
                              color: _copied ? AppColors.success : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _copied ? 'COPIED' : 'COPY',
                              style: AppTypography.codeSmall.copyWith(
                                fontSize: 10,
                                color: _copied ? AppColors.success : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              style: AppTypography.code.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
