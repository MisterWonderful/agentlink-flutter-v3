import 'package:flutter/material.dart';

/// Design tokens extracted from Stitch "AI Terminal Chat Interface" designs.
class AppColors {
  AppColors._();

  // ── Backgrounds ──────────────────────────────────────────────
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color cardBg = Color(0x0DFFFFFF); // white/5%

  // ── Text ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF3F3F3);
  static const Color textDim = Color(0xFF888888);
  static const Color textSecondary = Color(0xFF555555);
  static const Color textThought = Color(0xFFA3A3A3);

  // ── Accents ──────────────────────────────────────────────────
  static const Color accentCyan = Color(0xFF00F0FF);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentNeonPurple = Color(0xFFBD00FF);

  // ── Status ───────────────────────────────────────────────────
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFD97706);
  static const Color errorText = Color(0xFFFF3D3D);

  // ── Log severity colors ──────────────────────────────────────
  static const Color logInfo = Color(0xFF3B82F6);
  static const Color logDebug = Color(0xFFA78BFA); // purple-400
  static const Color logApi = Color(0xFF10B981); // emerald-500
  static const Color logWarn = Color(0xFFF59E0B); // amber-500
  static const Color logError = Color(0xFFD97706); // amber-600
  static const Color logAuth = Color(0xFFEC4899); // pink-600
  static const Color logAgent = Color(0xFF3B82F6);
  static const Color logDb = Color(0xFFCA8A04); // yellow-600
  static const Color logNet = Color(0xFF0891B2); // cyan-600
  static const Color logSys = Color(0xFF737373); // neutral-500

  // ── Glass morphism ───────────────────────────────────────────
  static const Color glassBg = Color(0x990A0A0A); // rgba(10,10,10,0.6)
  static const Color glassBorder = Color(0x1AFFFFFF); // white/10%
  static const Color dockBg = Color(0xE5000000); // black/90%

  // ── Borders & dividers ───────────────────────────────────────
  static const Color divider = Color(0x1AFFFFFF); // white/10%
  static const Color cardBorder = Color(0x14FFFFFF); // white/8%
  static const Color border = Color(0x26FFFFFF); // white/15%
}
