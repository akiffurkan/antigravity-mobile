import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Utilities for high-performance, OLED-friendly glassmorphism.
class GlassDecorations {
  GlassDecorations._();

  static BoxDecoration container({
    Color? fillColor,
    Color? borderColor,
    double borderRadius = 16.0,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: fillColor ?? AppColors.glassFill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.glassBorder,
        width: 1.0,
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
    );
  }

  static BoxDecoration glowingContainer({
    required Color glowColor,
    Color? fillColor,
    double borderRadius = 16.0,
  }) {
    return BoxDecoration(
      color: fillColor ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: glowColor.withOpacity(0.4),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withOpacity(0.15),
          blurRadius: 20,
          spreadRadius: -2,
        ),
      ],
    );
  }

  static Widget backdrop({
    required Widget child,
    double sigma = 10.0,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}
