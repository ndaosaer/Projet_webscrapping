import 'package:flutter/material.dart';
import 'ocean_colors.dart';
import 'providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Accès rapide aux couleurs adaptatives depuis n'importe quel écran.
/// Usage : final t = ThemeHelper.of(context);
///         Text('hello', style: TextStyle(color: t.textPrimary))
class ThemeHelper {
  final bool isDark;

  const ThemeHelper(this.isDark);

  static ThemeHelper of(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return ThemeHelper(isDark);
  }

  // ── Textes ─────────────────────────────────────────────────────────────────
  Color get textPrimary => isDark ? Colors.white           : OceanColors.lightText;
  Color get textMuted   => isDark ? OceanColors.w70        : OceanColors.lightMuted;
  Color get textHint    => isDark ? OceanColors.w50        : const Color(0xFF94A3B8);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  Color get cardBg      => isDark ? OceanColors.w15        : Colors.white;
  Color get cardBorder  => isDark ? OceanColors.w30        : OceanColors.lightBorder;
  Color get surface     => isDark ? OceanColors.w08        : OceanColors.lightSurface;
  Color get divider     => isDark ? OceanColors.w15        : OceanColors.lightBorder;

  // ── Accents ────────────────────────────────────────────────────────────────
  Color get accent      => isDark ? OceanColors.cyan       : OceanColors.lightBlue;
  Color get accentSoft  => isDark ? OceanColors.w15        : const Color(0xFFE8F2FF);
  Color get gold        => OceanColors.gold;

  // ── Sémantique ─────────────────────────────────────────────────────────────
  Color get positive    => OceanColors.positive;
  Color get negative    => OceanColors.negative;
  Color get neutral     => OceanColors.neutral;

  // ── Plateformes ────────────────────────────────────────────────────────────
  Color platformColor(String platform) {
    switch (platform) {
      case 'amazon':      return const Color(0xFFFF9900);
      case 'jumia_sn':    return const Color(0xFFF68B1E);
      case 'googlemaps':  return const Color(0xFF4285F4);
      default:            return const Color(0xFF00AF87);
    }
  }

  String platformName(String platform) {
    switch (platform) {
      case 'amazon':      return 'Amazon';
      case 'jumia_sn':    return 'Jumia SN';
      case 'googlemaps':  return 'Google Maps';
      default:            return 'TripAdvisor';
    }
  }

  Color sentimentColor(String? sentiment) {
    switch (sentiment) {
      case 'positive': return OceanColors.positive;
      case 'negative': return OceanColors.negative;
      default:         return OceanColors.neutral;
    }
  }

  // ── Styles TextStyle prêts à l'emploi ──────────────────────────────────────
  TextStyle get titleStyle => TextStyle(
      color: textPrimary, fontSize: 20,
      fontWeight: FontWeight.w700, fontFamily: 'Poppins');

  TextStyle get subtitleStyle => TextStyle(
      color: textMuted, fontSize: 12, fontFamily: 'Poppins');

  TextStyle get bodyStyle => TextStyle(
      color: textMuted, fontSize: 13, fontFamily: 'Poppins');

  TextStyle get labelStyle => TextStyle(
      color: textPrimary, fontSize: 12,
      fontWeight: FontWeight.w600, fontFamily: 'Poppins');

  // ── Décorations de conteneurs ──────────────────────────────────────────────
  BoxDecoration cardDecoration({double radius = 14, Color? border}) =>
      BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? cardBorder, width: 1),
      );

  BoxDecoration accentDecoration(Color color, {double radius = 14}) =>
      BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      );
}
