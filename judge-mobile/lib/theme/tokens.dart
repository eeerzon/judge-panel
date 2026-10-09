// Design tokens — ported 1:1 from judge-prototype/assets/css/tokens.css.
// Source of truth: _docs/design/design-system.md §2 (FROZEN). Do not add a new
// hex here unless no existing token is close in meaning (design-system §12).

import 'package:flutter/material.dart';

/// One complete set of colour tokens. [AppPalette.kreen] is the frozen
/// design-system palette (design-system.md §2); Judge Mode may swap in a
/// palette derived from an event theme ([AppPalette.fromHue]).
class AppPalette {
  const AppPalette({
    required this.bgBase,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textSecondary,
    required this.accent,
    required this.accentBright,
    required this.accentDeep,
    required this.accentSoft,
  });

  final Color bgBase, surface, surfaceAlt, surfaceRaised, border, borderStrong;
  final Color textSecondary;
  final Color accent, accentBright, accentDeep, accentSoft;

  // Deep burgundy / wine-black base, not neutral gray; gold/bronze accent
  // scale used sparingly (labels, numbers, active borders).
  static const kreen = AppPalette(
    bgBase: Color(0xFF12090A),
    surface: Color(0xFF1B1215),
    surfaceAlt: Color(0xFF22171B),
    surfaceRaised: Color(0xFF2A1D21),
    border: Color(0xFF3A2B2F),
    borderStrong: Color(0xFF4A3439),
    textSecondary: Color(0xFFB8A89B),
    accent: Color(0xFFC89B4B),
    accentBright: Color(0xFFD4AF6A),
    accentDeep: Color(0xFF8C6A35),
    accentSoft: Color.fromRGBO(200, 155, 75, 0.14),
  );

  /// The KREEN palette re-tinted to [hue]: backgrounds keep their (very
  /// dark) saturation/lightness; accents and secondary text keep their
  /// perceived brightness, so contrast stays the same on every theme.
  factory AppPalette.fromHue(double hue) {
    Color tint(Color c) => HSLColor.fromColor(c).withHue(hue).toColor().withValues(alpha: c.a);
    Color same(Color c) => _withLuminance(HSLColor.fromColor(c).withHue(hue), c.computeLuminance()).withValues(alpha: c.a);
    const k = kreen;
    return AppPalette(
      bgBase: tint(k.bgBase),
      surface: tint(k.surface),
      surfaceAlt: tint(k.surfaceAlt),
      surfaceRaised: tint(k.surfaceRaised),
      border: tint(k.border),
      borderStrong: tint(k.borderStrong),
      textSecondary: same(k.textSecondary),
      accent: same(k.accent),
      accentBright: same(k.accentBright),
      accentDeep: same(k.accentDeep),
      accentSoft: same(k.accentSoft),
    );
  }

  /// [hsl] with the lightness that gives [target] relative luminance.
  static Color _withLuminance(HSLColor hsl, double target) {
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (hsl.withLightness(mid).toColor().computeLuminance() < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hsl.withLightness((lo + hi) / 2).toColor();
  }
}

class AppColors {
  AppColors._();

  /// Active palette. Judge Mode routes set it per event theme before they
  /// build (see JudgeNav); everything else uses [AppPalette.kreen].
  static AppPalette palette = AppPalette.kreen;

  static Color get bgBase => palette.bgBase;
  static Color get surface => palette.surface;
  static Color get surfaceAlt => palette.surfaceAlt;
  static Color get surfaceRaised => palette.surfaceRaised;
  static Color get border => palette.border;
  static Color get borderStrong => palette.borderStrong;

  static const textPrimary = Color(0xFFF6F1E8);
  static Color get textSecondary => palette.textSecondary;

  static Color get accent => palette.accent;
  static Color get accentBright => palette.accentBright;
  static Color get accentDeep => palette.accentDeep;
  static Color get accentSoft => palette.accentSoft;

  // Scored is the only solid-fill status: it must be spotted at a glance
  // across a full grid. Draft / Not Scored stay muted on purpose. Status
  // colours never follow an event theme.
  static const statusScoredFill = Color(0xFF1E9E5C);
  static const statusScoredFillBorder = Color(0xFF167A47);
  static const statusScoredText = Color(0xFFF3FFF6);
  static const statusScoredIcon = Color(0xFFC8F7DC);
  static const statusScoredGlow = Color.fromRGBO(30, 158, 92, 0.35);

  static const statusDraftColor = Color(0xFFD9B76B);
  static const statusDraftBg = Color.fromRGBO(200, 155, 75, 0.14);
  static const statusDraftBorder = Color.fromRGBO(200, 155, 75, 0.38);

  static const statusErrorColor = Color(0xFFE0897A);

  static const success = Color(0xFF8FBF9E);

  // Dev-panel only (deliberately looks like a debug tool, not product UI).
  static const devPanelBg = Color.fromRGBO(18, 9, 10, 0.96);
  static const devPanelBorder = Color.fromRGBO(184, 168, 155, 0.35);
}

class AppLayout {
  AppLayout._();

  /// Cap for the Scoring Page header/body/footer on ultra-wide screens.
  static const scoringShellMaxWidth = 1600.0;

  /// Cap for the Contestant Gallery on wide screens.
  static const galleryMaxWidth = 1500.0;
}

const kFontFamily = 'Inter';
const kMonoFontFamily = 'monospace';

const kTabular = [FontFeature.tabularFigures()];

/// Small helper so every text style in the app reads like its CSS rule:
/// size/weight/color plus letter-spacing expressed in `em` like the CSS.
TextStyle ts(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double letterSpacingEm = 0,
  double? height,
  bool tabular = false,
}) {
  return TextStyle(
    fontFamily: kFontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    letterSpacing: letterSpacingEm * size,
    height: height,
    fontFeatures: tabular ? kTabular : null,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: kFontFamily,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgBase,
    canvasColor: AppColors.bgBase,
    colorScheme: ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.accent,
      secondary: AppColors.accentBright,
      error: AppColors.statusErrorColor,
      onSurface: AppColors.textPrimary,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accentBright,
      selectionColor: AppColors.accent.withValues(alpha: 0.35),
      selectionHandleColor: AppColors.accent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
  );
}
