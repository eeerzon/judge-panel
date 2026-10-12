// Shared Judge-mode building blocks. Each maps to a CSS component in
// judge-prototype/assets/css/components.css (named in the doc comment).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../theme/tokens.dart';

/// Tap target with the prototype's `:active { transform: scale(.96) }`
/// feedback and button semantics. No Material ripple (dark-room, minimal motion).
/// Text back link ("← Rounds", "← My Rounds"…). The label is a little
/// larger than body links and the whole box is tappable — at least 48×48
/// plus room to the right — so it is not missed on a physical device.
class BackLink extends StatelessWidget {
  const BackLink(this.label, {super.key, required this.onTap, this.color, this.minHeight = 48});

  /// Without the arrow ("Rounds" → "← Rounds").
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        semanticLabel: 'Back to $label',
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight, minWidth: 48),
          padding: const EdgeInsets.only(right: 20),
          alignment: Alignment.centerLeft,
          child: Text('← $label', style: ts(15, weight: FontWeight.w600, color: color ?? AppColors.textSecondary)),
        ),
      );
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 80),
          child: widget.child,
        ),
      ),
    );
  }
}

enum AppButtonVariant {
  /// transparent + border (scoring-back-btn, standby-action, modal secondary)
  outline,

  /// surface-alt + border (scoring-nav-btn)
  neutral,

  /// accent-soft + accent-deep border (review-cta-btn, scoring-nav-btn-primary,
  /// round-card-action, modal-btn-primary, entry-btn)
  primary,

  /// solid Scored fill (review-footer-btn.is-ready) — reuses the Scored token
  ready,
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.variant = AppButtonVariant.primary,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.radius = 10,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
    this.textColor,
    this.expand = false,
    this.leading,
    this.trailing,
    this.disabledOpacity = 0.35,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.palette,
  });

  /// Colours of another theme than the page's (e.g. a round card of another
  /// event on My Rounds). Null = the page palette.
  final AppPalette? palette;

  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final double height;
  final EdgeInsets padding;
  final double radius;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? textColor;
  final bool expand;
  final Widget? leading;
  final Widget? trailing;
  final double disabledOpacity;
  final Alignment alignment;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = palette ?? AppColors.palette;
    final (Color bg, Color border, Color fg) = switch (variant) {
      AppButtonVariant.outline => (Colors.transparent, p.border, p.textPrimary),
      AppButtonVariant.neutral => (p.surfaceAlt, p.border, p.textPrimary),
      AppButtonVariant.primary => (p.accentSoft, p.accentDeep, p.textPrimary),
      AppButtonVariant.ready => (
          AppColors.statusScoredFill,
          AppColors.statusScoredFillBorder,
          AppColors.statusScoredText
        ),
    };
    final enabled = onTap != null;
    Widget text = Text(
      label,
      textAlign: alignment == Alignment.centerLeft ? TextAlign.left : TextAlign.center,
      style: ts(fontSize, weight: fontWeight, color: textColor ?? fg, height: 1.25),
    );
    return Opacity(
      opacity: enabled ? 1 : disabledOpacity,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        semanticLabel: semanticLabel,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          width: expand ? double.infinity : null,
          padding: padding,
          alignment: expand ? alignment : null,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: alignment == Alignment.centerLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              // entry-btn: label left, trailing icon pushed to the right edge.
              if (expand && trailing != null) Expanded(child: text) else Flexible(child: text),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small round dot used inside status chips / connection indicator.
class Dot extends StatelessWidget {
  const Dot({super.key, required this.color, this.size = 7, this.glow});
  final Color color;
  final double size;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow == null ? null : [BoxShadow(color: glow!, blurRadius: 6)],
      ),
    );
  }
}

/// `.contestant-status` chip (Gallery card). Scored = solid fill + glow;
/// Draft/Not Scored stay muted. Never color-only: always text + dot.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.info});
  final StatusInfo info;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, Color border, Color dot, FontWeight weight, bool glow) = switch (info.status) {
      ScoreStatus.scored => (
          AppColors.statusScoredText,
          AppColors.statusScoredFill,
          AppColors.statusScoredFillBorder,
          AppColors.statusScoredIcon,
          FontWeight.w700,
          true
        ),
      ScoreStatus.draft => (
          AppColors.statusDraftColor,
          AppColors.statusDraftBg,
          AppColors.statusDraftBorder,
          AppColors.statusDraftColor,
          FontWeight.w600,
          false
        ),
      ScoreStatus.notStarted => (
          AppColors.textSecondary,
          AppColors.surfaceAlt,
          AppColors.border,
          AppColors.textSecondary,
          FontWeight.w600,
          false
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        boxShadow: glow ? const [BoxShadow(color: AppColors.statusScoredGlow, blurRadius: 10)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Dot(color: dot, glow: glow ? AppColors.statusScoredIcon : null, size: 7),
          const SizedBox(width: 6),
          Flexible(child: Text(info.label, style: ts(14, weight: weight, color: fg))),
        ],
      ),
    );
  }
}

/// Fallback hues (only if a photo is missing/fails) — jewel tones.
const kPhotoHues = [345, 38, 275, 8, 25, 155, 320, 50, 300, 15, 165, 260, 335, 60, 200];

/// Title prefixes stripped before computing initials ("Miss Yuka" → "Y").
const kNameTitles = ['mrs', 'miss', 'mister', 'mr', 'ms'];

/// Contestant photo (`poster_finalis`), cover-cropped. While loading, or if
/// it is missing/fails, shows the prototype's jewel-tone gradient (hue per
/// number) + initials.
class ContestantPhoto extends StatelessWidget {
  const ContestantPhoto({super.key, required this.contestant, this.initialsSize = 40, this.showInitials = true});

  final Contestant contestant;
  final double initialsSize;
  final bool showInitials;

  static String initials(String name) => name
      .split(' ')
      .where((p) => p.isNotEmpty && !kNameTitles.contains(p.toLowerCase()))
      .take(2)
      .map((p) => p[0])
      .join()
      .toUpperCase();

  static Gradient fallbackGradient(int number) {
    final hue = kPhotoHues[(number - 1).abs() % kPhotoHues.length].toDouble();
    // CSS `linear-gradient(160deg, …)`: 0deg points up, clockwise.
    const angle = 160 * math.pi / 180;
    final dx = math.sin(angle), dy = -math.cos(angle);
    return LinearGradient(
      begin: Alignment(-dx, -dy),
      end: Alignment(dx, dy),
      colors: [
        HSLColor.fromAHSL(1, hue, 0.32, 0.22).toColor(),
        HSLColor.fromAHSL(1, hue, 0.28, 0.12).toColor(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: showInitials
          ? Text(
              initials(contestant.name),
              style: ts(initialsSize, weight: FontWeight.w700, color: const Color.fromRGBO(246, 241, 232, 0.4)),
            )
          : const SizedBox.shrink(),
    );
    final url = contestant.photoUrl;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: fallbackGradient(contestant.number)),
      child: url == null
          ? fallback
          : Image.network(
              url,
              // Web: /img_up/ sends no CORS header → an <img> element shows it anyway.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              frameBuilder: (_, child, frame, wasSync) => wasSync || frame != null ? child : fallback,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// `.filter-pill` with its count bubble.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: expand ? 12 : 20),
          decoration: BoxDecoration(
            color: active ? AppColors.accentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: active ? AppColors.accent : AppColors.border),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(16, weight: FontWeight.w600, color: active ? AppColors.textPrimary : AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: ts(13,
                      weight: FontWeight.w700,
                      color: active ? AppColors.bgBase : AppColors.textSecondary,
                      tabular: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.connection-status` — dot + text. Offline is the only loud state.
class ConnectionStatusView extends StatelessWidget {
  const ConnectionStatusView({super.key, required this.state});
  final ConnectionStateKind state;

  @override
  Widget build(BuildContext context) {
    final (String text, Color dot, Color? glow, Color textColor, FontWeight weight) = switch (state) {
      ConnectionStateKind.online => ('Online', AppColors.textSecondary, null, AppColors.textSecondary, FontWeight.w400),
      ConnectionStateKind.syncing => ('Syncing…', AppColors.textSecondary, null, AppColors.textSecondary, FontWeight.w400),
      ConnectionStateKind.synced => (
          'Synced',
          AppColors.success,
          const Color.fromRGBO(143, 191, 158, 0.5),
          AppColors.textSecondary,
          FontWeight.w400
        ),
      ConnectionStateKind.offline => (
          'Offline',
          AppColors.statusErrorColor,
          const Color.fromRGBO(224, 137, 122, 0.5),
          AppColors.statusErrorColor,
          FontWeight.w600
        ),
    };
    return Semantics(
      label: 'Connection: $text',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Dot(color: dot, glow: glow),
          const SizedBox(width: 7),
          Text(text, style: ts(13, weight: weight, color: textColor)),
        ],
      ),
    );
  }
}

/// Uppercase, letter-spaced gold round label (`.gallery-round`,
/// `.scoring-round`, `.review-round`, `.submitted-round`).
class RoundLabel extends StatelessWidget {
  const RoundLabel(this.text, {super.key, this.color, this.size = 13, this.spacingEm = 0.24});
  final String text;

  /// Defaults to [AppColors.accentBright].
  final Color? color;
  final double size;
  final double spacingEm;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: ts(size, weight: FontWeight.w600, color: color ?? AppColors.accentBright, letterSpacingEm: spacingEm),
    );
  }
}

/// Centers [child] and caps its width (CSS `max-width` + `margin: auto`).
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.maxWidth, required this.child});
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

String formatScore(double v) => v.toStringAsFixed(2);

String twoDigits(int v) => v.toString().padLeft(2, '0');

String formatClock(DateTime d) => '${twoDigits(d.hour)}:${twoDigits(d.minute)}';

bool isPortrait(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.height > size.width;
}
