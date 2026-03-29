import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'ocean_colors.dart';

// ── Scaffold adaptatif light/dark ─────────────────────────────────────────────
class GlassScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;

  const GlassScaffold({super.key, required this.body, this.floatingActionButton});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? OceanColors.darkGradient
              : OceanColors.lightGradient,
        ),
        child: body,
      ),
    );
  }
}


// ── Helper contexte ───────────────────────────────────────────────────────────
extension ThemeCtx on BuildContext {
  bool get isDark => Provider.of<ThemeProvider>(this, listen: false).isDarkMode;

  Color get cardColor     => isDark ? OceanColors.w15        : OceanColors.lightCard;
  Color get cardBorder    => isDark ? OceanColors.w30        : OceanColors.lightBorder;
  Color get surfaceColor  => isDark ? OceanColors.w08        : OceanColors.lightSurface;
  Color get textPrimary   => isDark ? Colors.white           : OceanColors.lightText;
  Color get textMuted     => isDark ? OceanColors.w50        : OceanColors.lightMuted;
  Color get accent        => isDark ? OceanColors.cyan       : OceanColors.lightBlue;
}

// ── GlassCard adaptative ──────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? fillColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.borderColor,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg     = fillColor ?? (isDark ? OceanColors.w15 : OceanColors.lightCard);
    final border = borderColor ?? (isDark ? OceanColors.w30 : OceanColors.lightBorder);

    Widget content = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );

    if (isDark) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: content,
        ),
      );
    }
    return content;
  }
}

// ── GlassColorCard adaptative ─────────────────────────────────────────────────
class GlassColorCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const GlassColorCard({
    super.key,
    required this.child,
    required this.gradientColors,
    this.padding,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? gradientColors
              : gradientColors.map((c) => c.withOpacity(
                  c.opacity > 0.3 ? 0.12 : 0.06)).toList(),
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? gradientColors.first.withOpacity(0.4)
              : gradientColors.first.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────
class GlassLoading extends StatelessWidget {
  const GlassLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(context.accent),
        ),
        const SizedBox(height: 12),
        Text('Chargement...', style: TextStyle(
            color: context.textMuted, fontSize: 12,
            fontFamily: 'Poppins')),
      ]),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────
class GlassError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const GlassError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44,
              color: OceanColors.negative.withOpacity(0.7)),
          const SizedBox(height: 14),
          Text('API non disponible',
              style: TextStyle(color: context.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          const SizedBox(height: 6),
          Text('Vérifie que l\'API tourne sur localhost:8000',
              style: TextStyle(color: context.textMuted, fontSize: 12,
                  fontFamily: 'Poppins'),
              textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: context.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.accent.withOpacity(0.4)),
                ),
                child: Text('Réessayer',
                    style: TextStyle(color: context.accent, fontSize: 13,
                        fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────
class GlassBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const GlassBadge({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(
            color: c, fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins')),
      ]),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────
class GlassSectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const GlassSectionTitle({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: context.accent),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
          color: context.textPrimary, fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins')),
    ]);
  }
}

// ── SearchBar ─────────────────────────────────────────────────────────────────
class GlassSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const GlassSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint = 'Rechercher...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accent;
    final focused = focusNode?.hasFocus ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark ? OceanColors.w08 : OceanColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? accent
              : (isDark ? OceanColors.w30 : OceanColors.lightBorder),
          width: focused ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(
            color: context.textPrimary, fontSize: 14,
            fontFamily: 'Poppins'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textMuted, fontSize: 14,
              fontFamily: 'Poppins'),
          prefixIcon: Icon(Icons.search_rounded,
              color: focused ? accent : context.textMuted, size: 18),
          suffixIcon: controller.text.isNotEmpty && onClear != null
              ? IconButton(
                  icon: Icon(Icons.cancel_rounded,
                      color: context.textMuted, size: 16),
                  onPressed: onClear)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

// ── Toggle theme button ───────────────────────────────────────────────────────
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final tp     = Provider.of<ThemeProvider>(context);
    final isDark = tp.isDarkMode;
    return GestureDetector(
      onTap: tp.toggleTheme,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? OceanColors.w15 : OceanColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? OceanColors.w30 : OceanColors.lightBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 14,
              color: isDark ? OceanColors.gold : OceanColors.lightBlue),
          const SizedBox(width: 6),
          Text(isDark ? 'Clair' : 'Sombre',
              style: TextStyle(
                  color: isDark ? OceanColors.gold : OceanColors.lightBlue,
                  fontSize: 11, fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins')),
        ]),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class GlassFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const GlassFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c      = color ?? context.accent;
    final isDark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? c.withOpacity(isDark ? 0.2 : 0.12)
              : (isDark ? OceanColors.w15 : OceanColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? c.withOpacity(0.6)
                : (isDark ? OceanColors.w30 : OceanColors.lightBorder),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12,
            color: selected ? c : context.textMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontFamily: 'Poppins')),
      ),
    );
  }
}
