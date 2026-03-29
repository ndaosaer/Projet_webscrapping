import 'package:flutter/material.dart';

/// Palette Bleu Océan — source unique de vérité
/// Importé par theme_provider.dart ET glass_widgets.dart
class OceanColors {
  // ── Dark mode — fonds ──────────────────────────────────────────────────────
  static const Color darkBg1 = Color(0xFF050D1A);
  static const Color darkBg2 = Color(0xFF0A1628);
  static const Color darkBg3 = Color(0xFF0D2040);
  static const Color darkBg4 = Color(0xFF103060);

  // ── Accents ────────────────────────────────────────────────────────────────
  static const Color cyan     = Color(0xFF00D4FF);
  static const Color teal     = Color(0xFF00B4CC);
  static const Color blue     = Color(0xFF3B82F6);
  static const Color gold     = Color(0xFFFFBB00);

  // ── Sémantique ─────────────────────────────────────────────────────────────
  static const Color positive = Color(0xFF22D3A5);
  static const Color negative = Color(0xFFFF5F7E);
  static const Color neutral  = Color(0xFF7EB8F7);

  // ── Blancs (dark mode) ─────────────────────────────────────────────────────
  static const Color w90 = Color(0xE6FFFFFF);
  static const Color w70 = Color(0xB3FFFFFF);
  static const Color w50 = Color(0x80FFFFFF);
  static const Color w30 = Color(0x4DFFFFFF);
  static const Color w15 = Color(0x26FFFFFF);
  static const Color w08 = Color(0x14FFFFFF);

  // ── Light mode ─────────────────────────────────────────────────────────────
  static const Color lightBg      = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF0F7FF);
  static const Color lightCard    = Color(0xFFFFFFFF);
  static const Color lightBorder  = Color(0xFFCFDFF5);
  static const Color lightCyan    = Color(0xFF0099BB);
  static const Color lightBlue    = Color(0xFF1D6FE8);
  static const Color lightText    = Color(0xFF0A1628);
  static const Color lightMuted   = Color(0xFF64748B);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF050D1A),
      Color(0xFF0A1628),
      Color(0xFF0D2040),
      Color(0xFF103060),
    ],
    stops: [0.0, 0.3, 0.65, 1.0],
  );

  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF0F7FF),
      Color(0xFFE8F2FF),
    ],
  );
}
