import 'package:flutter/material.dart';

/// UniEvent brand palette (see System Proposal §3.2.1).
class AppColors {
  AppColors._();

  static const Color royalViolet = Color(0xFF6D28D9);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color electricBlue = Color(0xFF3B82F6);
  static const Color midnight = Color(0xFF1E1B4B);
  static const Color orange = Color(0xFFF97316);
  static const Color green = Color(0xFF16A34A);
  static const Color red = Color(0xFFDC2626);
  static const Color cloud = Color(0xFFF6F7FB);
  static const Color white = Color(0xFFFFFFFF);

  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color surfaceTint = Color(0xFFEEF0FF);

  /// Signature violet → indigo → blue gradient.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [royalViolet, indigo, electricBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [royalViolet, indigo, electricBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Category accent colours so students can scan the feed quickly.
  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'cultural':
        return royalViolet;
      case 'career':
        return indigo;
      case 'technical':
        return electricBlue;
      case 'creative':
        return orange;
      case 'sports':
        return green;
      case 'social':
        return const Color(0xFFDB2777);
      default:
        return midnight;
    }
  }
}
