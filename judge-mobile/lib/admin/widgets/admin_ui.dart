// Admin UI primitives — port of judge-prototype/admin/admin.css components.
// Colors come from the shared tokens (admin-design-system: no Admin palette).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/tokens.dart';
import '../../widgets/common.dart' show Pressable, Dot;

/// Admin-only surfaces that the CSS hard-codes next to the tokens.
class AdminColors {
  AdminColors._();
  static const sidebar = Color(0xFF160C0E);
  static const navIcon = Color(0xFFB69B75);
  static const navDisabled = Color(0xFF9D9087);
  static const contextBar = Color.fromRGBO(27, 18, 21, 0.78);
  static const successTint = Color.fromRGBO(143, 191, 158, 0.12);
  static const successBorder = Color.fromRGBO(143, 191, 158, 0.45);
  static const errorTint = Color.fromRGBO(224, 137, 122, 0.10);
  static const errorBorder = Color.fromRGBO(224, 137, 122, 0.50);
  static const modalBarrier = Color.fromRGBO(8, 4, 4, 0.72);
}

/// Breakpoints from admin.css (viewport-based, like the CSS media queries).
class AdminLayout {
  AdminLayout._();

  /// `(orientation: portrait), (max-width: 760px)` → bottom nav, stacked rows.
  static bool compact(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return s.width <= 760 || s.height > s.width;
  }

  /// `(max-width: 1100px) and landscape` → 208px sidebar, 2-col grids, stacked tables.
  static bool narrow(BuildContext context) => MediaQuery.sizeOf(context).width <= 1100 || compact(context);

  static bool tiny(BuildContext context) => MediaQuery.sizeOf(context).width <= 520;

  /// stat / round grid columns.
  static int gridColumns(BuildContext context, {int wide = 4}) =>
      tiny(context) ? 1 : (narrow(context) ? 2 : wide);
}

// ------------------------------------------------------------------ icons

/// `adminIconPaths` from admin-navigation.js (24×24, stroke 1.9, round caps).
const _iconPaths = {
  'home': '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z"/>',
  'rounds':
      '<rect x="5" y="4" width="14" height="5" rx="1.5"/><rect x="3" y="10" width="18" height="5" rx="1.5"/><rect x="5" y="16" width="14" height="5" rx="1.5"/>',
  'person': '<circle cx="12" cy="7.5" r="3.5"/><path d="M5 21v-2a7 7 0 0 1 14 0v2z"/>',
  'judges':
      '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="9" cy="10" r="2.5"/><path d="M5.5 16a3.5 3.5 0 0 1 7 0M15 9h3M15 13h3M15 17h2"/>',
  'live':
      '<circle cx="12" cy="12" r="2.5"/><path d="M7.5 7.5a6.4 6.4 0 0 0 0 9M16.5 7.5a6.4 6.4 0 0 1 0 9M4.5 4.5a10.6 10.6 0 0 0 0 15M19.5 4.5a10.6 10.6 0 0 1 0 15"/>',
  'results': '<path d="M4 20h16M5 20v-7h4v7M10 20V5h4v15M15 20v-10h4v10"/>',
  'settings':
      '<circle cx="12" cy="12" r="3"/><path d="M10 2.5h4l.5 2.1 1.5.7 1.9-1.2 2.8 2.8-1.2 1.9.7 1.5 2.1.5v4l-2.1.5-.7 1.5 1.2 1.9-2.8 2.8-1.9-1.2-1.5.7-.5 2.1h-4l-.5-2.1-1.5-.7-1.9 1.2-2.8-2.8 1.2-1.9-.7-1.5-2.1-.5v-4l2.1-.5.7-1.5-1.2-1.9 2.8-2.8 1.9 1.2 1.5-.7z"/>',
  'history': '<path d="M3.5 8A9 9 0 1 1 3 13M3.5 3.5V8H8"/><path d="M12 7v5l3.5 2"/>',
  'more':
      '<circle cx="4" cy="12" r="1.65" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.65" fill="currentColor" stroke="none"/><circle cx="20" cy="12" r="1.65" fill="currentColor" stroke="none"/>',
  'switch': '<path d="M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4"/>',
  'logout': '<path d="M10 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h5M14 7l5 5-5 5M19 12H9"/>',
  // Glyphs the prototype writes as text (⌕ ▾ ↳) but Inter does not contain.
  'search': '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m15.5 15.5 5 5"/>',
  'caret': '<path d="m6 9 6 6 6-6" fill="currentColor"/>',
  'child': '<path d="M6 4v9a3 3 0 0 0 3 3h10m-4-4 4 4-4 4"/>',
};

class AdminIcon extends StatelessWidget {
  const AdminIcon(this.name, {super.key, this.size = 20, this.color = AdminColors.navIcon});
  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$hex" '
        'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" color="$hex">'
        '${(_iconPaths[name] ?? _iconPaths['more']!).replaceAll('currentColor', hex)}</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

// ---------------------------------------------------------------- buttons

enum AdminBtnVariant { normal, primary, success, danger }

/// `.admin-btn` (+ `-primary`, `-success`, `-danger`, `-small`).
class AdminBtn extends StatelessWidget {
  const AdminBtn(
    this.label, {
    super.key,
    this.onTap,
    this.variant = AdminBtnVariant.normal,
    this.small = false,
    this.expand = false,
  });
  final String label;
  final VoidCallback? onTap;
  final AdminBtnVariant variant;
  final bool small;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg) = switch (variant) {
      AdminBtnVariant.normal => (AppColors.surfaceAlt, AppColors.border, AppColors.textPrimary),
      AdminBtnVariant.primary => (AppColors.accentSoft, AppColors.accentDeep, AppColors.textPrimary),
      AdminBtnVariant.success => (AppColors.statusScoredFill, AppColors.statusScoredFillBorder, AppColors.statusScoredText),
      AdminBtnVariant.danger => (
          const Color.fromRGBO(224, 137, 122, 0.10),
          const Color.fromRGBO(224, 137, 122, 0.65),
          AppColors.statusErrorColor
        ),
    };
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          constraints: BoxConstraints(minHeight: small ? 40 : 46),
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: small ? 13 : 17),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Center(
            widthFactor: expand ? null : 1,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: ts(small ? 13 : 14, weight: FontWeight.w700, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.admin-icon-btn` (e.g. "×" close).
class AdminIconBtn extends StatelessWidget {
  const AdminIconBtn({super.key, required this.label, required this.onTap, this.semanticLabel});
  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: ts(19, color: AppColors.textSecondary)),
      ),
    );
  }
}

// ----------------------------------------------------------------- badges

const _statusLabels = {
  'open': 'Open',
  'draft': 'Draft',
  'closed': 'Closed',
  'finalized': 'Finalized',
  'submitted': 'Submitted',
  'resubmitted': 'Resubmitted',
  'reopened': 'Reopened',
  'excused': 'Excused',
  'removed': 'Removed',
  'in-progress': 'In Progress',
  'not-started': 'Not Started',
  'assigned': 'Assigned',
  'unassigned': 'Unassigned',
  'active': 'Active',
  'inactive': 'Inactive',
  'scored': 'Scored',
  'non-scored': 'Non-scored',
};

/// `.admin-status` — always text + dot. Draft/in-progress = muted gold,
/// open/active/assigned = subtle green, finalized/submitted = solid green,
/// removed/offline = coral, the rest neutral.
class AdminStatus extends StatelessWidget {
  const AdminStatus(this.value, {super.key, this.label});
  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg, bool glow) = switch (value) {
      'draft' || 'in-progress' || 'reopened' || 'needs-attention' => (
          AppColors.statusDraftBg,
          AppColors.statusDraftBorder,
          AppColors.statusDraftColor,
          false
        ),
      'open' || 'active' || 'assigned' || 'scored' || 'online' || 'completed' => (
          AdminColors.successTint,
          AdminColors.successBorder,
          AppColors.success,
          false
        ),
      'finalized' || 'submitted' || 'resubmitted' => (
          AppColors.statusScoredFill,
          AppColors.statusScoredFillBorder,
          AppColors.statusScoredText,
          true
        ),
      'removed' || 'offline' || 'error' || 'blocked' => (
          AdminColors.errorTint,
          AdminColors.errorBorder,
          AppColors.statusErrorColor,
          false
        ),
      _ => (AppColors.surfaceAlt, AppColors.border, AppColors.textSecondary, false),
    };
    return _Chip(
      bg: bg,
      border: border,
      fg: fg,
      glow: glow,
      text: label ?? _statusLabels[value] ?? (value.isEmpty ? '' : value[0].toUpperCase() + value.substring(1)),
    );
  }
}

/// `.admin-connection` (Synced / Syncing / Offline).
class AdminConnection extends StatelessWidget {
  const AdminConnection(this.connection, {super.key});
  final String connection;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg, String text) = switch (connection) {
      'offline' => (AdminColors.errorTint, AdminColors.errorBorder, AppColors.statusErrorColor, 'Offline'),
      'syncing' => (AppColors.statusDraftBg, AppColors.statusDraftBorder, AppColors.statusDraftColor, 'Syncing'),
      _ => (AdminColors.successTint, AdminColors.successBorder, AppColors.success, 'Synced'),
    };
    return _Chip(bg: bg, border: border, fg: fg, text: text, dotSize: 7);
  }
}

/// `.admin-readiness-state` (Ready / Review).
class AdminReadyChip extends StatelessWidget {
  const AdminReadyChip(this.ready, {super.key});
  final bool ready;

  @override
  Widget build(BuildContext context) => ready
      ? const _Chip(bg: AdminColors.successTint, border: AdminColors.successBorder, fg: AppColors.success, text: 'Ready', dot: false)
      : const _Chip(
          bg: AppColors.statusDraftBg, border: AppColors.statusDraftBorder, fg: AppColors.statusDraftColor, text: 'Review', dot: false);
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.bg,
    required this.border,
    required this.fg,
    required this.text,
    this.glow = false,
    this.dot = true,
    this.dotSize = 6,
  });
  final Color bg, border, fg;
  final String text;
  final bool glow, dot;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        boxShadow: glow ? const [BoxShadow(color: Color.fromRGBO(30, 158, 92, 0.18), blurRadius: 9)] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Dot(color: fg, size: dotSize), const SizedBox(width: 7)],
        Flexible(
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, weight: FontWeight.w700, color: fg, height: 1.2)),
        ),
      ]),
    );
  }
}

/// `.admin-round-chip`
class AdminRoundChip extends StatelessWidget {
  const AdminRoundChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        // width: fit-content — chips sit side by side and wrap only when needed.
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(text, style: ts(11, weight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
      );
}

// ----------------------------------------------------------------- layout

/// `.admin-panel` (and `.admin-stat-card` / `.admin-round-card` surface).
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.child, this.padding = EdgeInsets.zero, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: child,
      );
}

/// Grid with equal-height rows (CSS grid `repeat(n, 1fr)`).
class AdminGrid extends StatelessWidget {
  const AdminGrid({super.key, required this.columns, required this.children, this.gap = 16});
  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) SizedBox(width: gap),
              Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()),
            ],
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// `.admin-page-header`
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({super.key, this.eyebrow, required this.title, this.description, this.actions = const []});
  final String? eyebrow;
  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final compact = AdminLayout.compact(context);
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (eyebrow != null) ...[AdminEyebrow(eyebrow!), const SizedBox(height: 7)],
      Text(title, style: ts(compact ? 26 : 30, weight: FontWeight.w700, letterSpacingEm: -0.025, height: 1.2)),
      if (description != null) ...[
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Text(description!, style: ts(15, color: AppColors.textSecondary, height: 1.55)),
        ),
      ],
    ]);
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 24 : 30),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              text,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 17),
                AdminLayout.tiny(context)
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gapped(actions, 10, vertical: true))
                    : Row(children: _gapped([for (final a in actions) Expanded(child: a)], 10)),
              ],
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: text),
              if (actions.isNotEmpty) ...[const SizedBox(width: 24), ..._gapped(actions, 10)],
            ]),
    );
  }
}

List<Widget> _gapped(List<Widget> items, double gap, {bool vertical = false}) => [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) SizedBox(width: vertical ? 0 : gap, height: vertical ? gap : 0),
        items[i],
      ],
    ];

/// `.admin-eyebrow`
class AdminEyebrow extends StatelessWidget {
  const AdminEyebrow(this.text, {super.key, this.color});
  final String text;

  /// Defaults to [AppColors.accentBright].
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: ts(12, weight: FontWeight.w700, color: color ?? AppColors.accentBright, letterSpacingEm: 0.15));
}

/// `.admin-section-heading`
class AdminSectionHeading extends StatelessWidget {
  const AdminSectionHeading({super.key, required this.title, this.subtitle, this.trailing = const []});
  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 32, bottom: 14),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: ts(18, weight: FontWeight.w700, letterSpacingEm: -0.01)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: ts(13, color: AppColors.textSecondary)),
              ],
            ]),
            if (trailing.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: trailing),
          ],
        ),
      );
}

/// `.admin-stat-card`
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({super.key, this.value, this.valueWidget, required this.label, this.note, this.noteWidget});
  final String? value;
  final Widget? valueWidget;
  final String label;
  final String? note;
  final Widget? noteWidget;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 122),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          valueWidget ??
              Text(value ?? '', style: ts(28, weight: FontWeight.w700, letterSpacingEm: -0.025, tabular: true, height: 1.2)),
          const SizedBox(height: 7),
          Text(label, style: ts(13, weight: FontWeight.w600, color: AppColors.textSecondary)),
          if (noteWidget != null || note != null) ...[
            const SizedBox(height: 4),
            noteWidget ?? Text(note!, style: ts(12, weight: FontWeight.w600, color: AppColors.success)),
          ],
        ]),
      );
}

class AdminStatGrid extends StatelessWidget {
  const AdminStatGrid(this.cards, {super.key});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: AdminGrid(columns: AdminLayout.gridColumns(context), children: cards),
      );
}

/// `.admin-progress` (8px).
class AdminProgress extends StatelessWidget {
  const AdminProgress(this.percentage, {super.key, this.green = false});
  final int percentage;
  final bool green;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 8,
          color: AppColors.surfaceRaised,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (percentage / 100).clamp(0, 1),
            heightFactor: 1,
            child: ColoredBox(color: green ? AppColors.statusScoredFill : AppColors.accent),
          ),
        ),
      );
}

/// `.admin-lock-note`
class AdminLockNote extends StatelessWidget {
  const AdminLockNote(this.text, {super.key, this.locked = false, this.child});
  final String text;
  final bool locked;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: locked ? const Color.fromRGBO(210, 120, 102, 0.45) : AppColors.border),
          ),
          child: child ??
              Text(text,
                  style: ts(12, color: locked ? AppColors.statusErrorColor : AppColors.textSecondary, height: 1.4)),
        ),
      );
}

/// `.admin-warning`
class AdminWarning extends StatelessWidget {
  const AdminWarning({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.statusDraftBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.statusDraftBorder),
        ),
        child: DefaultTextStyle(
          style: ts(13, weight: FontWeight.w600, color: AppColors.statusDraftColor, height: 1.45),
          child: child,
        ),
      );
}

/// Inline text link inside notes/warnings.
class AdminLink extends StatelessWidget {
  const AdminLink(this.text, {super.key, required this.onTap, this.color = AppColors.textPrimary});
  final String text;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text,
              style: ts(13, weight: FontWeight.w700, color: color).copyWith(decoration: TextDecoration.underline, decorationColor: color)),
        ),
      );
}

/// `.admin-state` empty / error card.
class AdminStateCard extends StatelessWidget {
  const AdminStateCard({super.key, required this.title, this.description, this.action, this.error = false, this.icon = '○'});
  final String title;
  final String? description;
  final Widget? action;
  final bool error;
  final String icon;

  @override
  Widget build(BuildContext context) => AdminPanel(
        padding: const EdgeInsets.all(30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 13),
            decoration: BoxDecoration(
              color: error ? AdminColors.errorTint : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: error ? AdminColors.errorBorder : AppColors.border),
            ),
            child: Text(icon, style: ts(18, color: error ? AppColors.statusErrorColor : AppColors.accentBright)),
          ),
          Text(title, style: ts(17, weight: FontWeight.w700)),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Text(description!, style: ts(14, color: AppColors.textSecondary, height: 1.55)),
              ),
            ),
          ?action,
        ]),
      );
}

/// `.admin-readiness-list`
class AdminReadinessList extends StatelessWidget {
  const AdminReadinessList(this.items, {super.key});
  final List<(String label, String detail, bool ready)> items;

  @override
  Widget build(BuildContext context) {
    final stacked = AdminLayout.tiny(context);
    return AdminPanel(
      child: Column(children: [
        for (var i = 0; i < items.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
            decoration: BoxDecoration(
              border: i == 0 ? null : Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Flex(
              direction: stacked ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Flexible(
                  fit: stacked ? FlexFit.loose : FlexFit.tight,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(items[i].$1, style: ts(14, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(items[i].$2, style: ts(12, color: AppColors.textSecondary)),
                  ]),
                ),
                SizedBox(width: stacked ? 0 : 18, height: stacked ? 7 : 0),
                AdminReadyChip(items[i].$3),
              ],
            ),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ inputs

/// `.admin-filter-pill`
class AdminFilterPill extends StatelessWidget {
  const AdminFilterPill(this.label, {super.key, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: active ? AppColors.accentSoft : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? AppColors.accentDeep : AppColors.border),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label,
                style: ts(13, weight: FontWeight.w700, color: active ? AppColors.textPrimary : AppColors.textSecondary)),
          ),
        ),
      );
}

InputDecoration adminFieldDecoration({String? hint, bool error = false, Widget? prefix}) {
  OutlineInputBorder b(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c));
  return InputDecoration(
    hintText: hint,
    hintStyle: ts(14, color: AppColors.textSecondary),
    isDense: true,
    filled: true,
    fillColor: AppColors.surfaceAlt,
    constraints: const BoxConstraints(minHeight: 46),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minWidth: 39),
    enabledBorder: b(error ? AppColors.statusErrorColor : AppColors.border),
    disabledBorder: b(AppColors.border),
    focusedBorder: b(error ? AppColors.statusErrorColor : AppColors.accent),
  );
}

/// `.admin-search-wrap` + `.admin-field`
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        style: ts(14),
        decoration: adminFieldDecoration(
          hint: hint,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: AdminIcon('search', size: 16, color: AppColors.textSecondary),
          ),
        ),
      );
}

/// `.admin-field-label` + field.
class AdminFormField extends StatelessWidget {
  const AdminFormField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: ts(13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 7),
        child,
      ]);
}

/// `.admin-field` text input.
class AdminTextField extends StatelessWidget {
  const AdminTextField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.error = false,
    this.maxLines = 1,
    this.onChanged,
    this.autofocus = false,
    this.obscureText = false,
    this.isEnabled = true,
    this.inputFormatters,
  });
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool error;
  final bool isEnabled;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: isEnabled,
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 4 : 1,
        autofocus: autofocus,
        obscureText: obscureText,
        onChanged: onChanged,
        style: ts(14),
        decoration: adminFieldDecoration(hint: hint, error: error),
      );
}

/// `.admin-field` select.
class AdminSelect<T> extends StatelessWidget {
  const AdminSelect({super.key, required this.value, required this.items, required this.onChanged, this.enabled = true});
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: AppColors.surfaceRaised,
            iconEnabledColor: AppColors.textSecondary,
            iconDisabledColor: AppColors.border,
            style: ts(14),
            items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l, style: ts(14)))],
            disabledHint: Text(items.where((i) => i.$1 == value).firstOrNull?.$2 ?? '',
                style: ts(14, color: AppColors.textSecondary)),
            // A nullable T (e.g. Parent "None") must reach the caller too.
            onChanged: enabled ? (v) => onChanged(v as T) : null,
          ),
        ),
      );
}

/// `.admin-toggle` switch (48×28).
class AdminToggle extends StatelessWidget {
  const AdminToggle({super.key, required this.on, required this.onChanged, this.semanticLabel});
  final bool on;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: on,
        label: semanticLabel,
        child: Opacity(
          opacity: onChanged == null ? 0.5 : 1,
          child: GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(!on),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(4),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: on ? AppColors.statusScoredFill : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? AppColors.statusScoredFillBorder : AppColors.border),
              ),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? AppColors.statusScoredText : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Checkbox tinted like `accent-color: var(--accent)`.
class AdminCheckbox extends StatelessWidget {
  const AdminCheckbox({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: Checkbox(
          value: value,
          onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
          activeColor: AppColors.accent,
          checkColor: AppColors.bgBase,
          side: BorderSide(color: AppColors.borderStrong, width: 1.5),
        ),
      );
}

// ------------------------------------------------------------ modal / drawer

/// `.admin-modal`. [onConfirm] returns (or completes with) an error message
/// to keep the modal open (e.g. rejected governance action), or null to
/// close it. While an async [onConfirm] runs the confirm button is busy.
Future<bool> showAdminModal(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  AdminBtnVariant confirmVariant = AdminBtnVariant.primary,
  bool requireReason = false,
  String reasonLabel = 'Reason *',
  String? reasonHint,
  Widget? extra,
  required FutureOr<String?> Function(String reason) onConfirm,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AdminColors.modalBarrier,
    builder: (_) => _AdminModal(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      confirmVariant: confirmVariant,
      requireReason: requireReason,
      reasonLabel: reasonLabel,
      reasonHint: reasonHint,
      extra: extra,
      onConfirm: onConfirm,
    ),
  );
  return result == true;
}

class _AdminModal extends StatefulWidget {
  const _AdminModal({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmVariant,
    required this.requireReason,
    required this.reasonLabel,
    required this.reasonHint,
    required this.extra,
    required this.onConfirm,
  });
  final String title, body, confirmLabel, reasonLabel;
  final String? reasonHint;
  final AdminBtnVariant confirmVariant;
  final bool requireReason;
  final Widget? extra;
  final FutureOr<String?> Function(String reason) onConfirm;

  @override
  State<_AdminModal> createState() => _AdminModalState();
}

class _AdminModalState extends State<_AdminModal> {
  final _reason = TextEditingController();
  String? _error;
  late String _body = widget.body;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    if (widget.requireReason && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Reason is required.');
      return;
    }
    final pending = widget.onConfirm(_reason.text.trim());
    String? failure;
    if (pending is Future<String?>) {
      setState(() => _busy = true);
      failure = await pending;
      if (!mounted) return;
      setState(() => _busy = false);
    } else {
      failure = pending;
    }
    if (failure != null) {
      setState(() => _body = failure!);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final tiny = AdminLayout.tiny(context);
    final actions = [
      AdminBtn('Cancel', onTap: _busy ? null : () => Navigator.of(context).pop(false), expand: tiny),
      AdminBtn(_busy ? 'Working…' : widget.confirmLabel,
          onTap: _busy ? null : _confirm, variant: widget.confirmVariant, expand: tiny),
    ];
    return Dialog(
      backgroundColor: AppColors.surfaceRaised,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.borderStrong),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tiny ? 24 : 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.title, style: ts(22, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(_body, style: ts(15, color: AppColors.textSecondary, height: 1.55)),
            if (widget.extra != null) ...[const SizedBox(height: 14), widget.extra!],
            if (widget.requireReason) ...[
              const SizedBox(height: 18),
              Text(widget.reasonLabel, style: ts(13, weight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 7),
              AdminTextField(
                controller: _reason,
                hint: widget.reasonHint ?? 'Required reason',
                maxLines: 4,
                error: _error != null,
                autofocus: true,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 7),
                Text(_error!, style: ts(12, weight: FontWeight.w600, color: AppColors.statusErrorColor)),
              ],
            ],
            const SizedBox(height: 24),
            tiny
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gapped(actions.reversed.toList(), 10, vertical: true))
                : Row(mainAxisAlignment: MainAxisAlignment.end, children: _gapped(actions, 10)),
          ]),
        ),
      ),
    );
  }
}

/// `.admin-drawer` — right side sheet (full width on compact screens).
Future<T?> showAdminDrawer<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, StateSetter setState) body,
  required List<Widget> Function(BuildContext context, StateSetter setState) footer,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: AdminColors.modalBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) {
      final width = MediaQuery.sizeOf(context).width;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppColors.surface,
          child: Container(
            width: width < 480 ? width : 480,
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.borderStrong)),
              boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 60, offset: Offset(-24, 0))],
            ),
            child: SafeArea(
              left: false,
              child: StatefulBuilder(
                builder: (context, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 74),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                    child: Row(children: [
                      Expanded(child: Text(title, style: ts(20, weight: FontWeight.w700))),
                      AdminIconBtn(label: '×', semanticLabel: 'Close', onTap: () => Navigator.of(context).pop()),
                    ]),
                  ),
                  Expanded(
                    child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: body(context, setState)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
                      children: footer(context, setState),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// `.admin-detail-item` (drawer detail list).
class AdminDetailItem extends StatelessWidget {
  const AdminDetailItem({super.key, required this.label, this.value, this.valueWidget, this.note, this.last = false});
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? note;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(bottom: last ? 0 : 14),
        margin: EdgeInsets.only(bottom: last ? 0 : 15),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: AppColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: ts(12, weight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          valueWidget ?? Text(value ?? '', style: ts(14, weight: FontWeight.w700)),
          if (note != null) ...[const SizedBox(height: 5), Text(note!, style: ts(12, color: AppColors.textSecondary))],
        ]),
      );
}

/// Contestant photo / initials used across Admin pages.
class AdminPhoto extends StatelessWidget {
  const AdminPhoto({super.key, required this.photo, required this.name, this.fit = BoxFit.cover, this.initialsSize = 22});
  final String photo;
  final String name;
  final BoxFit fit;
  final double initialsSize;

  static String initials(String name) =>
      name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(initials(name.isEmpty ? '?' : name),
          style: ts(initialsSize, weight: FontWeight.w800, color: AppColors.accent, letterSpacingEm: 0.04)),
    );
    Widget image;
    if (photo.isEmpty) {
      image = fallback;
    } else if (photo.startsWith('assets/')) {
      image = Image.asset(photo, fit: fit, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => fallback);
    } else {
      // Web: /img_up/ sends no CORS header → an <img> element shows it anyway.
      image = Image.network(photo,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, _, _) => fallback);
    }
    return ColoredBox(color: AppColors.accentSoft, child: image);
  }
}

String adminTime(DateTime? value) =>
    value == null ? '—' : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String pct(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(2);
