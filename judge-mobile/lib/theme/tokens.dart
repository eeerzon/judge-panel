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
    this.textPrimary = const Color(0xFFF6F1E8),
    this.light = false,
  });

  final Color bgBase, surface, surfaceAlt, surfaceRaised, border, borderStrong;
  final Color textPrimary, textSecondary;
  final Color accent, accentBright, accentDeep, accentSoft;

  /// Light mode palette (night mode = false).
  final bool light;

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

  /// Light mode: warm ivory page, white cards, dark text; the gold accents
  /// are darker so they keep their contrast on light surfaces.
  static const kreenLight = AppPalette(
    bgBase: Color(0xFFF6F1EA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBF7F2),
    surfaceRaised: Color(0xFFFFFFFF),
    border: Color(0xFFE6DCD2),
    borderStrong: Color(0xFFD3C5B8),
    textPrimary: Color(0xFF1F1416),
    textSecondary: Color(0xFF6B5A50),
    accent: Color(0xFF8C6420),
    accentBright: Color(0xFF7A5615),
    accentDeep: Color(0xFFC89B4B),
    accentSoft: Color.fromRGBO(200, 155, 75, 0.16),
    light: true,
  );

  /// The KREEN palette of the mode.
  static AppPalette kreenFor({required bool light}) => light ? kreenLight : kreen;

  /// The KREEN palette (night or [light]) re-tinted to [hue]: backgrounds
  /// keep their saturation/lightness; accents and secondary text keep their
  /// perceived brightness, so contrast stays the same on every theme.
  factory AppPalette.fromHue(double hue, {bool light = false}) {
    Color tint(Color c) => HSLColor.fromColor(c).withHue(hue).toColor().withValues(alpha: c.a);
    Color same(Color c) => _withLuminance(HSLColor.fromColor(c).withHue(hue), c.computeLuminance()).withValues(alpha: c.a);
    final k = kreenFor(light: light);
    return AppPalette(
      textPrimary: k.textPrimary,
      light: light,
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

  /// Active palette. Every route sets it before it builds (JudgeNav): the
  /// event theme in Judge Mode, else KREEN — in night or light mode.
  static AppPalette palette = AppPalette.kreen;

  /// Light mode is on (the palette says so).
  static bool get light => palette.light;

  static Color get bgBase => palette.bgBase;
  static Color get surface => palette.surface;
  static Color get surfaceAlt => palette.surfaceAlt;
  static Color get surfaceRaised => palette.surfaceRaised;
  static Color get border => palette.border;
  static Color get borderStrong => palette.borderStrong;

  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;

  static Color get accent => palette.accent;
  static Color get accentBright => palette.accentBright;
  static Color get accentDeep => palette.accentDeep;
  static Color get accentSoft => palette.accentSoft;

  // Scored is the only solid-fill status: it must be spotted at a glance
  // across a full grid. Draft / Not Scored stay muted on purpose. Status
  // colours never follow an event theme; in light mode the text-like ones
  // are darker for contrast.
  static const statusScoredFill = Color(0xFF1E9E5C);
  static const statusScoredFillBorder = Color(0xFF167A47);
  static const statusScoredText = Color(0xFFF3FFF6);
  static const statusScoredIcon = Color(0xFFC8F7DC);
  static const statusScoredGlow = Color.fromRGBO(30, 158, 92, 0.35);

  /// "Scored / saved" as text on the page (not on the green fill, where
  /// [statusScoredIcon] is used): pale green at night, deep green in light.
  static Color get statusScoredOnPage => light ? const Color(0xFF2E7D4F) : statusScoredIcon;

  /// Card shadow strength: soft at night, very light in light mode.
  static Color get cardShadow => Color.fromRGBO(0, 0, 0, light ? 0.07 : 0.18);

  static Color get statusDraftColor => light ? const Color(0xFF8A6516) : const Color(0xFFD9B76B);
  static Color get statusDraftBg => light ? const Color.fromRGBO(200, 155, 75, 0.16) : const Color.fromRGBO(200, 155, 75, 0.14);
  static Color get statusDraftBorder =>
      light ? const Color.fromRGBO(160, 120, 50, 0.45) : const Color.fromRGBO(200, 155, 75, 0.38);

  static Color get statusErrorColor => light ? const Color(0xFFB2412C) : const Color(0xFFE0897A);

  static Color get success => light ? const Color(0xFF2E7D4F) : const Color(0xFF8FBF9E);

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

/// [backgroundPicture]: the page has a theme picture behind it (Judge Mode,
/// see ThemedBackground), so scaffolds stay see-through.
ThemeData buildAppTheme({bool backgroundPicture = false}) {
  final light = AppColors.light;
  final base = ThemeData(
    brightness: light ? Brightness.light : Brightness.dark,
    useMaterial3: true,
    fontFamily: kFontFamily,
  );
  return base.copyWith(
    scaffoldBackgroundColor: backgroundPicture ? Colors.transparent : AppColors.bgBase,
    canvasColor: AppColors.bgBase,
    colorScheme: (light ? ColorScheme.light : ColorScheme.dark)(
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
