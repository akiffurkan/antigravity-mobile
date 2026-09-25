import 'package:flutter/material.dart';

/// Centralized Obsidian Titanium Cyber Dark Color Palette for Antigravity Mobile.
/// Strictly adheres to Obsidian Deep Black + Metallic Graphite + Precision Cyan + Glassmorphism.
class AppColors {
  AppColors._();

  // Dark & Obsidian Backgrounds
  static const Color background = Color(0xFF07080B);
  static const Color surface = Color(0xFF0E1017);
  static const Color surfaceElevated = Color(0xFF141722);
  static const Color cardBackground = Color(0xFF161924);
  static const Color cardBorder = Color(0xFF232838);
  static const Color cardBorderLight = Color(0xFF32384E);

  // Brand / Titanium / Cyber Glow Accents
  static const Color titanium = Color(0xFFF1F5F9);
  static const Color titaniumMuted = Color(0xFF94A3B8);
  static const Color primary = Color(0xFF00E5FF);        // Antigravity Cyber Cyan
  static const Color primaryGlow = Color(0x3300E5FF);    // 20% opacity glow
  static const Color secondary = Color(0xFF6366F1);      // Electric Indigo
  static const Color accent = Color(0xFF38BDF8);

  // Status & Risk Colors
  static const Color success = Color(0xFF10B981);       // Emerald
  static const Color successGlow = Color(0x3310B981);
  static const Color warning = Color(0xFFF59E0B);       // Amber Gold
  static const Color warningGlow = Color(0x33F59E0B);
  static const Color danger = Color(0xFFEF4444);        // Crimson
  static const Color dangerGlow = Color(0x33EF4444);
  static const Color critical = Color(0xFFFF1E56);      // Critical Neon Red

  // Text Colors (High Contrast Obsidian Hierarchy)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textCode = Color(0xFFE2E8F0);

  // Glassmorphic & Metallic Layer Tokens
  static const Color glassFill = Color(0x12FFFFFF);     // ~7% white over obsidian
  static const Color glassFillHover = Color(0x1FFFFFFF);// 12% white
  static const Color glassBorder = Color(0x28FFFFFF);   // Subtle metallic rim
  static const Color glassBorderLight = Color(0x40FFFFFF);

  // Terminal & Monospace
  static const Color codeBackground = Color(0xFF0A0C12);
  static const Color codeBorder = Color(0xFF1E2333);
}
