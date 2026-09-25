import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

enum RiskLevel {
  low,
  medium,
  high,
  critical;

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'LOW RISK';
      case RiskLevel.medium:
        return 'MEDIUM RISK';
      case RiskLevel.high:
        return 'HIGH RISK';
      case RiskLevel.critical:
        return 'CRITICAL RISK';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.low:
        return AppColors.success;
      case RiskLevel.medium:
        return AppColors.warning;
      case RiskLevel.high:
        return AppColors.danger;
      case RiskLevel.critical:
        return AppColors.critical;
    }
  }

  static RiskLevel fromString(String? value) {
    if (value == null) return RiskLevel.medium;
    switch (value.toUpperCase()) {
      case 'LOW':
      case 'LOW_RISK':
        return RiskLevel.low;
      case 'MEDIUM':
      case 'MEDIUM_RISK':
        return RiskLevel.medium;
      case 'HIGH':
      case 'HIGH_RISK':
        return RiskLevel.high;
      case 'CRITICAL':
      case 'CRITICAL_RISK':
        return RiskLevel.critical;
      default:
        return RiskLevel.medium;
    }
  }
}
