import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

enum LogoSize {
  small(24, 10, 0),
  medium(44, 13, 1),
  large(68, 16, 2),
  hero(96, 20, 3);

  final double iconSize;
  final double fontSize;
  final double letterSpacing;
  const LogoSize(this.iconSize, this.fontSize, this.letterSpacing);
}

/// Central Antigravity Logo with premium breathing aura and futuristic diamond insignia.
class AntigravityLogo extends StatefulWidget {
  final LogoSize size;
  final bool showText;
  final String? subtitle;
  final bool animate;
  final Color? glowColor;

  const AntigravityLogo({
    super.key,
    this.size = LogoSize.medium,
    this.showText = true,
    this.subtitle,
    this.animate = true,
    this.glowColor,
  });

  @override
  State<AntigravityLogo> createState() => _AntigravityLogoState();
}

class _AntigravityLogoState extends State<AntigravityLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AntigravityLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGlow = widget.glowColor ?? const Color(0xFF328AFF);

    Widget logoGlyph = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.animate ? _pulseAnimation.value : 1.0;
        final glowOpacity = widget.animate ? _glowAnimation.value : 0.2;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size.iconSize,
            height: widget.size.iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: effectiveGlow.withOpacity(glowOpacity * 0.4),
                  blurRadius: widget.size.iconSize * 0.4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size.iconSize / 4),
              child: Image.asset(
                'assets/images/antigravity_logo.png',
                width: widget.size.iconSize,
                height: widget.size.iconSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return CustomPaint(
                    painter: _AntigravityInsigniaPainter(
                      coreColor: AppColors.titanium,
                      glowColor: effectiveGlow,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (!widget.showText && widget.subtitle == null) {
      return logoGlyph;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoGlyph,
        if (widget.showText) ...[
          const SizedBox(height: 12),
          Text(
            'ANTIGRAVITY',
            style: AppTypography.titleSmall.copyWith(
              fontSize: widget.size.fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: widget.size.letterSpacing + 1.8,
              color: AppColors.titanium,
            ),
          ),
        ],
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!.toUpperCase(),
            style: AppTypography.bodySmall.copyWith(
              fontSize: (widget.size.fontSize * 0.7).clamp(9.0, 12.0),
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _AntigravityInsigniaPainter extends CustomPainter {
  final Color coreColor;
  final Color glowColor;

  _AntigravityInsigniaPainter({
    required this.coreColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Concentric thin orbital halo
    final ringPaint = Paint()
      ..color = glowColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.95, ringPaint);

    // 2. Outer Diamond (Rotated Square 45 deg)
    final outerDiamondPath = Path();
    final dSize = radius * 0.7;
    outerDiamondPath.moveTo(center.dx, center.dy - dSize);
    outerDiamondPath.lineTo(center.dx + dSize, center.dy);
    outerDiamondPath.lineTo(center.dx, center.dy + dSize);
    outerDiamondPath.lineTo(center.dx - dSize, center.dy);
    outerDiamondPath.close();

    final outerPaint = Paint()
      ..color = AppColors.cardBackground
      ..style = PaintingStyle.fill;
    canvas.drawPath(outerDiamondPath, outerPaint);

    final borderPaint = Paint()
      ..color = glowColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(outerDiamondPath, borderPaint);

    // 3. Inner Core Diamond
    final innerPath = Path();
    final inSize = radius * 0.35;
    innerPath.moveTo(center.dx, center.dy - inSize);
    innerPath.lineTo(center.dx + inSize, center.dy);
    innerPath.lineTo(center.dx, center.dy + inSize);
    innerPath.lineTo(center.dx - inSize, center.dy);
    innerPath.close();

    final corePaint = Paint()
      ..color = coreColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, corePaint);
  }

  @override
  bool shouldRepaint(covariant _AntigravityInsigniaPainter oldDelegate) =>
      oldDelegate.coreColor != coreColor || oldDelegate.glowColor != glowColor;
}
