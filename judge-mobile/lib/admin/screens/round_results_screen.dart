// admin/round-results.html — provisional / official results, tie
// acknowledgement, finalize, advancement entry, judge visibility
// (admin-results-ui.js `renderRound`). All calculation lives in AdminStore.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import '../widgets/admin_rows.dart';
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';

class AdminRoundResultsScreen extends StatelessWidget {
  const AdminRoundResultsScreen({super.key, required this.roundId});
  final String roundId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final round = admin.getRound(roundId)!;
    final result = admin.calculateRoundResults(roundId);

    if (!result.available) {
      return RoundWorkspace(
        roundId: roundId,
        activeTab: RoundTab.results,
        pageTitle: 'Official Results',
        pageDescription: 'Combined contestant scores for eligible Required judges.',
        children: [
          AdminStateCard(
            title: 'Results unavailable',
            description: result.reason,
            action: AdminBtn('View Round Overview', onTap: () => AdminNav.round(context, AdminRoutes.roundOverview, roundId)),
          ),
          _AdvancementPanel(store: admin, round: round, finalized: false),
          _VisibilityControl(store: admin, roundId: roundId, finalized: false),
        ],
      );
    }

    if (!result.finalized) admin.noteResultsCalculated(roundId);
    final percent = admin.resultsAsPercent;
    if (!percent && result.items.any((i) => i.rawScore == null) && !admin.isLoadingRawScores(roundId)) {
      // Raw view opened (or kept from an earlier page): load the per-judge detail.
      WidgetsBinding.instance.addPostFrameCallback((_) => admin.loadRawScores(roundId));
    }
    final rawMax = admin.rawMaxScore(roundId);
    final finalized = result.finalized;
    final tieBlocked = result.hasTie && !admin.isTieAcknowledged(roundId);
    final narrow = AdminLayout.narrow(context);

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.results,
      pageTitle: 'Official Results',
      pageDescription: 'Combined contestant scores for eligible Required judges.',
      children: [
        // .admin-result-state
        AdminPanel(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 14,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                AdminEyebrow(finalized ? 'Finalized Official Result' : 'Provisional Admin Result'),
                const SizedBox(height: 7),
                Text(finalized ? 'Official results locked' : 'Results calculated', style: ts(19, weight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(
                  '${result.eligibleJudgeCount} eligible judges · ${result.contestantCount} contestants · '
                  '${finalized ? (result.finalizedBy == null ? 'Finalized' : 'Finalized by ${result.finalizedBy}') : 'Not finalized yet'}',
                  style: ts(13, color: AppColors.textSecondary),
                ),
              ]),
              finalized
                  ? const AdminStatus('finalized')
                  : AdminBtn('Finalize Results',
                      variant: AdminBtnVariant.primary, onTap: tieBlocked ? null : () => _finalize(context, admin, round)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResultScaleToggle(roundId: roundId),
        const SizedBox(height: 16),
        AdminStatGrid([
          AdminStatCard(value: '${result.contestantCount}', label: 'Contestants'),
          AdminStatCard(value: '${result.eligibleJudgeCount}', label: 'Eligible Judges'),
          const AdminStatCard(value: '100%', label: 'Required submissions'),
          AdminStatCard(valueWidget: Align(alignment: Alignment.centerLeft, child: AdminStatus(round.status)), label: 'Round status'),
        ]),
        if (result.hasTie) ...[
          AdminWarning(
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
              Text('Tie detected.', style: ts(13, weight: FontWeight.w700, color: AppColors.statusDraftColor)),
              const Text('A final tie-break rule has not yet been configured. Equal scores share a rank; no winner is invented.'),
              if (finalized)
                const Text('Acknowledged before finalization.')
              else if (admin.isTieAcknowledged(roundId))
                Text('Tie acknowledged.', style: ts(13, weight: FontWeight.w700, color: AppColors.statusDraftColor))
              else
                AdminBtn('Acknowledge Tie', small: true, onTap: () => admin.acknowledgeTie(roundId)),
            ]),
          ),
          const SizedBox(height: 18),
        ],
        AdminList(
          header: narrow
              ? null
              : const AdminListHead(columns: [('Rank', 3), ('Contestant', 14), ('Combined score', 7), ('Judges', 5), ('', 0)]),
          children: [
            for (final item in result.items)
              ResultRow(
                item: item,
                percent: percent,
                rawMax: rawMax,
                loadingRaw: admin.isLoadingRawScores(roundId),
                onDetail: () => AdminNav.round(context, AdminRoutes.resultDetail, roundId, contestantId: item.contestantId),
              ),
          ],
        ),
        _AdvancementPanel(store: admin, round: round, finalized: finalized),
        _VisibilityControl(store: admin, roundId: roundId, finalized: finalized),
      ],
    );
  }

  void _finalize(BuildContext context, AdminStore admin, AdminRound round) {
    showAdminModal(
      context,
      title: 'Finalize ${round.name} Results?',
      body: 'This will lock the official result snapshot. Normal score and submission editing will remain unavailable.',
      confirmLabel: 'Finalize Results',
      onConfirm: (_) => admin.finalizeAction(roundId),
    );
  }
}

/// `.admin-result-row`
class ResultRow extends StatelessWidget {
  const ResultRow({super.key, required this.item, this.onDetail, this.percent = true, this.rawMax = 0, this.loadingRaw = false});
  final ResultItem item;
  final VoidCallback? onDetail;

  /// true = 0–100 (server avg_score); false = raw points of [rawMax].
  final bool percent;
  final double rawMax;
  final bool loadingRaw;

  @override
  Widget build(BuildContext context) {
    final narrow = AdminLayout.narrow(context);
    final rank = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${item.rank}', style: ts(22, weight: FontWeight.w700, color: AppColors.accentBright, tabular: true)),
      if (item.tied) Text('TIED', style: ts(10, weight: FontWeight.w700, color: AppColors.accentBright, letterSpacingEm: 0.06)),
    ]);
    final person = Row(children: [
      ResultAvatar(item: item),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item.numberLabel} · ${item.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(item.profesi, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, color: AppColors.textSecondary)),
        ]),
      ),
    ]);
    final (value, outOf) = resultScoreText(item, percent: percent, rawMax: rawMax, loading: loadingRaw);
    final score = Text.rich(TextSpan(children: [
      TextSpan(text: value, style: ts(19, weight: FontWeight.w700, tabular: true)),
      TextSpan(text: outOf, style: ts(12, color: AppColors.textSecondary)),
    ]));
    final judges = Text('${item.eligibleJudgeCount} Judges', style: ts(12, color: AppColors.textSecondary));
    final action = onDetail == null ? null : AdminBtn('View Detail', small: true, onTap: onDetail);

    if (narrow) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 42, child: rank),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              person,
              const SizedBox(height: 8),
              score,
              const SizedBox(height: 4),
              judges,
              if (action != null && AdminLayout.tiny(context)) ...[const SizedBox(height: 10), action],
            ]),
          ),
          if (action != null && !AdminLayout.tiny(context)) ...[const SizedBox(width: 10), action],
        ]),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(children: [
        Expanded(flex: 3, child: rank),
        const SizedBox(width: 14),
        Expanded(flex: 14, child: person),
        const SizedBox(width: 14),
        Expanded(flex: 7, child: score),
        const SizedBox(width: 14),
        Expanded(flex: 5, child: judges),
        const SizedBox(width: 14),
        SizedBox(width: 90, child: action),
      ]),
    );
  }
}

class ResultAvatar extends StatelessWidget {
  const ResultAvatar({super.key, required this.item, this.size = 42});
  final ResultItem item;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: item.photo.isEmpty
            ? Center(child: Text(item.numberLabel, style: ts(12, weight: FontWeight.w800, color: AppColors.accent)))
            : AdminPhoto(photo: item.photo, name: item.name, initialsSize: 12),
      );
}

/// `.admin-result-visibility` — advancement entry / final note.
class _AdvancementPanel extends StatelessWidget {
  const _AdvancementPanel({required this.store, required this.round, required this.finalized});
  final AdminStore store;
  final AdminRound round;
  final bool finalized;

  @override
  Widget build(BuildContext context) {
    final next = store.getNextRound(round.id);
    if (next == null) {
      if (!finalized) return const SizedBox.shrink();
      return const _SidePanel(
        eyebrow: 'Final Results',
        title: 'End of judging progression',
        body: 'This is the final round. No further advancement is available.',
      );
    }
    if (!finalized) {
      return _SidePanel(
        eyebrow: 'Advancement · Next Round ${next.name}',
        title: 'Advancement unavailable',
        body: 'Finalize this round before selecting contestants for the next round.',
      );
    }
    final record = store.getAdvancement(round.id);
    final count = store.advancementSlots(round.id);
    return _SidePanel(
      eyebrow: 'Advancement · Next Round ${next.name}',
      title: record != null ? '${record.selectedContestantIds.length} contestants advanced' : 'Qualified 0 / $count',
      body: record != null
          ? 'Confirmed ${adminDateTime(record.confirmedAt)}${record.method == 'manual' ? ' · Manual adjustment' : ''}'
          : 'Review the official ranking before confirming advancement.',
      note: record != null && record.reason.isNotEmpty ? 'Reason: ${record.reason}' : null,
      trailing: Wrap(spacing: 8, runSpacing: 8, children: [
        if (record != null) ...[
          AdminBtn('View ${next.name}',
              variant: AdminBtnVariant.primary, onTap: () => AdminNav.round(context, AdminRoutes.roundOverview, next.id)),
          if (next.status == 'draft')
            AdminBtn('Reset Advancement', variant: AdminBtnVariant.danger, onTap: () => _reset(context)),
        ] else
          AdminBtn('Select Advancing Contestants',
              variant: AdminBtnVariant.primary, onTap: () => AdminNav.round(context, AdminRoutes.advancement, round.id)),
      ]),
    );
  }

  void _reset(BuildContext context) {
    showAdminModal(
      context,
      title: 'Reset advancement?',
      body: 'This clears the target-round contestant assignment, preserves history, and does not change official results.',
      confirmLabel: 'Reset Advancement',
      confirmVariant: AdminBtnVariant.danger,
      requireReason: true,
      onConfirm: (reason) => store.resetAdvancementAction(round.id, reason),
    );
  }
}

class _VisibilityControl extends StatelessWidget {
  const _VisibilityControl({required this.store, required this.roundId, required this.finalized});
  final AdminStore store;
  final String roundId;
  final bool finalized;

  @override
  Widget build(BuildContext context) {
    final on = store.isResultVisible(roundId);
    return _SidePanel(
      title: 'Judge Results Visibility',
      body: 'When enabled, judges assigned to this round can view the official ranking and combined scores.',
      note: finalized ? (on ? 'Visible to judges' : 'Hidden from judges') : 'Judges can only view results after finalization.',
      trailing: AdminToggle(
        on: on,
        semanticLabel: 'Allow Judges to View Results',
        onChanged: finalized
            ? (v) async {
                final messenger = ScaffoldMessenger.of(context);
                final error = await store.setResultVisibilityAction(roundId, v);
                if (error != null) {
                  messenger.showSnackBar(SnackBar(
                    backgroundColor: AppColors.surfaceRaised,
                    content: Text(error, style: ts(14)),
                  ));
                }
              }
            : null,
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({this.eyebrow, required this.title, required this.body, this.note, this.trailing});
  final String? eyebrow;
  final String title, body;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (eyebrow != null) ...[AdminEyebrow(eyebrow!), const SizedBox(height: 7)],
      Text(title, style: ts(17, weight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(body, style: ts(13, color: AppColors.textSecondary)),
      if (note != null) ...[const SizedBox(height: 5), Text(note!, style: ts(13, color: AppColors.accentBright))],
    ]);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: AdminPanel(
        padding: const EdgeInsets.all(20),
        child: AdminLayout.tiny(context)
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, if (trailing != null) ...[const SizedBox(height: 14), trailing!]])
            : Row(children: [Expanded(child: text), if (trailing != null) ...[const SizedBox(width: 20), trailing!]]),
      ),
    );
  }
}

String adminDateTime(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${adminTime(d)}';


/// Final score as shown in Results: percent "63.33" + " / 100", or raw
/// points "880" + " / 1000" (… while the per-judge detail is loading).
(String, String) resultScoreText(ResultItem item, {required bool percent, required double rawMax, bool loading = false}) {
  if (percent) return (item.combinedScore.toStringAsFixed(2), ' / 100');
  final raw = item.rawScore;
  return (raw == null ? (loading ? '…' : '—') : pct(raw), ' / ${pct(rawMax)}');
}

/// Results header toggle — on (default): percent (0–100); off: raw points.
class ResultScaleToggle extends StatelessWidget {
  const ResultScaleToggle({super.key, required this.roundId});
  final String roundId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final percent = admin.resultsAsPercent;
    final rawMax = admin.rawMaxScore(roundId);
    return AdminPanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Show scores as percentage', style: ts(14, weight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              percent
                  ? 'Final scores on a 0–100 scale (weighted).'
                  : 'Raw points: the judges\' average total of criterion scores, out of ${pct(rawMax)}. '
                      'Ranking stays the official one.',
              style: ts(12, color: AppColors.textSecondary, height: 1.45),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        if (admin.isLoadingRawScores(roundId)) ...[
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBright)),
          const SizedBox(width: 12),
        ],
        AdminToggle(
          on: percent,
          semanticLabel: 'Show scores as percentage',
          onChanged: (v) {
            admin.setResultsAsPercent(v);
            if (!v) admin.loadRawScores(roundId);
          },
        ),
      ]),
    );
  }
}
