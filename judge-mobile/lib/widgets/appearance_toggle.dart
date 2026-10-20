// Night / light mode controls. Both read and flip AppearanceStore (via
// AppearanceScope); the icons are customisable:
//
//   AppearanceToggle(
//     nightIcon: Icon(Icons.nightlight_round, size: 16),   // any widget
//     lightIcon: Image.asset('assets/images/sun.png', width: 16),
//   )
//
// AppearanceToggle  — pill switch with the icon in its knob (top bars).
// AppearanceIconButton — a single round icon button (Mode Selector).

import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/tokens.dart';

/// Default icons: moon for night mode, sun for light mode.
Widget _defaultNight(double size) => Icon(Icons.dark_mode_rounded, size: size, color: const Color(0xFF1F1416));
Widget _defaultLight(double size) => Icon(Icons.light_mode_rounded, size: size, color: const Color(0xFF8C6420));

class AppearanceToggle extends StatelessWidget {
  const AppearanceToggle({super.key, this.nightIcon, this.lightIcon, this.width = 56, this.height = 30});

  /// Shown in the knob while night mode is on (default: a moon).
  final Widget? nightIcon;

  /// Shown in the knob while light mode is on (default: a sun).
  final Widget? lightIcon;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final store = AppearanceScope.of(context);
    final light = store.light;
    final knob = height - 6;
    return Semantics(
      button: true,
      toggled: light,
      label: light ? 'Light mode on. Switch to night mode' : 'Night mode on. Switch to light mode',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: store.toggle,
        // A 48px-tall hit area around the small pill.
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: (48 - height).clamp(0, 48) / 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            height: height,
            padding: const EdgeInsets.all(3),
            alignment: light ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: light ? const Color(0xFFF1E4CC) : const Color(0xFF2A1D21),
              borderRadius: BorderRadius.circular(height),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Container(
              width: knob,
              height: knob,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: light ? Colors.white : const Color(0xFFD4AF6A),
              ),
              child: light ? (lightIcon ?? _defaultLight(knob - 8)) : (nightIcon ?? _defaultNight(knob - 8)),
            ),
          ),
        ),
      ),
    );
  }
}

class AppearanceIconButton extends StatelessWidget {
  const AppearanceIconButton({super.key, this.nightIcon, this.lightIcon, this.size = 44});

  /// Shown while night mode is on (tap → light). Default: a moon.
  final Widget? nightIcon;

  /// Shown while light mode is on (tap → night). Default: a sun.
  final Widget? lightIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final store = AppearanceScope.of(context);
    final light = store.light;
    return Semantics(
      button: true,
      label: light ? 'Switch to night mode' : 'Switch to light mode',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: store.toggle,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceRaised,
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: light
              ? (lightIcon ?? Icon(Icons.light_mode_rounded, size: size * 0.5, color: AppColors.accent))
              : (nightIcon ?? Icon(Icons.dark_mode_rounded, size: size * 0.5, color: AppColors.accentBright)),
        ),
      ),
    );
  }
}
