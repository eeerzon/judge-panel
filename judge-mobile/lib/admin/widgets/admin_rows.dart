// Shared Admin cards/rows: `.admin-round-card` and `.admin-data-row`.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_store.dart';
import 'admin_ui.dart';

/// `.admin-round-card` (admin.js `roundCard`).
class AdminRoundCard extends StatelessWidget {
  const AdminRoundCard({super.key, required this.store, required this.round});
  final AdminStore store;
  final AdminRound round;

  @override
  Widget build(BuildContext context) {
    final ready = store.getRoundReadiness(round.id);
    final progress = ready.submissionSummary;
    final snapshot = store.getRoundResultStatus(round.id) == 'finalized' ? store.getResultSnapshot(round.id) : null;
    final advancement = store.getAdvancement(round.id);
    final incoming = store.getAdvancementForTarget(round.id);
    final previous = store.getPreviousRound(round.id);
    final note = advancement != null
        ? '${advancement.selectedContestantIds.length} advanced to ${store.getNextRound(round.id)!.name}'
        : snapshot != null
            ? 'Official Results Ready'
            : incoming != null
                ? 'Advanced from ${store.getRound(incoming.sourceRoundId)!.name}'
                : round.status == 'draft' && previous != null
                    ? '${previous.advancementCount ?? 0} expected from previous round'
                    : null;
    final (label, primary, route) = snapshot != null
        ? ('View Results', true, AdminRoutes.roundResults)
        : round.status == 'open'
            ? ('Open Round', true, AdminRoutes.roundOverview)
            : round.status == 'closed'
                ? ('View Round', false, AdminRoutes.roundOverview)
                : ('View Setup', false, AdminRoutes.roundOverview);

    Widget meta(String value, String caption) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: ts(15, weight: FontWeight.w700, tabular: true)),
          const SizedBox(height: 2),
          Text(caption, style: ts(12, color: AppColors.textSecondary, height: 1.35)),
        ]);

    return Container(
      constraints: const BoxConstraints(minHeight: 246),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${round.order.toString().padLeft(2, '0')} · ROUND',
                  style: ts(12, weight: FontWeight.w700, color: AppColors.accent, letterSpacingEm: 0.12)),
              const SizedBox(height: 9),
              Text(round.name, style: ts(20, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 12),
          AdminStatus(round.status),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: meta('${ready.contestantsAssigned}', 'Contestants')),
          const SizedBox(width: 10),
          Expanded(
            child: meta(snapshot != null ? '${snapshot.eligibleJudgeCount}' : '${ready.judgesAssigned}',
                snapshot != null ? 'Eligible Judges' : 'Judges'),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: meta('${ready.scoredCriteriaCount}', 'Criteria')),
          const SizedBox(width: 10),
          Expanded(child: meta('${progress.submitted} / ${progress.total}', 'Submitted')),
        ]),
        const SizedBox(height: 24),
        if (note != null) ...[
          Text(note, style: ts(13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
        ],
        const Spacer(),
        AdminBtn(
          label,
          expand: true,
          variant: primary ? AdminBtnVariant.primary : AdminBtnVariant.normal,
          onTap: () => AdminNav.round(context, route, round.id),
        ),
      ]),
    );
  }
}

/// Panel whose children are separated by a bottom border (`.admin-data-list`).
class AdminList extends StatelessWidget {
  const AdminList({super.key, required this.children, this.header});
  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) => AdminPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ?header,
          for (var i = 0; i < children.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i == 0 && header == null ? null : Border(top: BorderSide(color: AppColors.border)),
              ),
              child: children[i],
            ),
        ]),
      );
}

/// Uppercase column header row (`.admin-monitoring-head`, `.admin-config-head`).
class AdminListHead extends StatelessWidget {
  const AdminListHead({super.key, required this.columns});
  final List<(String, int)> columns; // label, flex (0 = auto)

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.centerLeft,
        child: Row(children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            columns[i].$2 == 0
                ? SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: _label(columns[i].$1)))
                : Expanded(flex: columns[i].$2, child: _label(columns[i].$1)),
          ],
        ]),
      );

  Widget _label(String t) =>
      Text(t.toUpperCase(), style: ts(11, weight: FontWeight.w700, color: AppColors.textSecondary, letterSpacingEm: 0.09));
}

/// `.admin-data-row`: name/subtext · meta · status · action. Stacks into two
/// columns on narrow / compact screens.
class AdminDataRow extends StatelessWidget {
  const AdminDataRow({
    super.key,
    required this.name,
    required this.subtext,
    required this.meta,
    required this.status,
    this.extra,
    this.trailing,
    this.action,
    this.actionWidth,
  });
  final String name, subtext, meta;
  final Widget status;
  final Widget? extra; // e.g. connection chip
  final String? trailing; // e.g. last sync
  final Widget? action;

  /// Fixed action column (matches an [AdminListHead] `(label, 0)` column).
  final double? actionWidth;

  @override
  Widget build(BuildContext context) {
    final narrow = AdminLayout.narrow(context);
    final primary = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, weight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(subtext, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, color: AppColors.textSecondary)),
    ]);
    final metaText = Text(meta, style: ts(13, color: AppColors.textSecondary));
    if (narrow) {
      return Padding(
        padding: const EdgeInsets.all(15),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              primary,
              const SizedBox(height: 10),
              metaText,
              if (extra != null) ...[const SizedBox(height: 10), extra!],
            ]),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            status,
            if (action != null) ...[const SizedBox(height: 10), action!],
            if (trailing != null) ...[
              const SizedBox(height: 10),
              Text(trailing!, style: ts(12, color: AppColors.textSecondary)),
            ],
          ]),
        ]),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Expanded(flex: 15, child: primary),
        const SizedBox(width: 14),
        Expanded(flex: 8, child: metaText),
        const SizedBox(width: 14),
        Expanded(flex: extra == null ? 10 : 8, child: Align(alignment: Alignment.centerLeft, child: status)),
        if (extra != null) ...[
          const SizedBox(width: 14),
          Expanded(flex: 7, child: Align(alignment: Alignment.centerLeft, child: extra!)),
        ],
        if (trailing != null) ...[
          const SizedBox(width: 14),
          Expanded(flex: 5, child: Text(trailing!, style: ts(13, color: AppColors.textSecondary))),
        ],
        if (action != null) ...[
          const SizedBox(width: 14),
          actionWidth == null ? action! : SizedBox(width: actionWidth, child: Align(alignment: Alignment.centerRight, child: action)),
        ],
      ]),
    );
  }
}

/// Monitoring row labels → status value.
String connectionLabel(String connection) =>
    connection == 'offline' ? 'Offline' : connection == 'syncing' ? 'Syncing' : 'Synced';

bool needsAttention(MonitoringJudge j) =>
    j.assignmentStatus == 'assigned' &&
    j.required &&
    (['not-started', 'in-progress', 'reopened'].contains(j.submissionStatus) || j.connection == 'offline');
