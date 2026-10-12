// admin/result-detail.html — one contestant's combined score and judge
// inclusion breakdown (admin-results-ui.js `renderDetail`).

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../../widgets/common.dart' show BackLink;
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';
import 'round_results_screen.dart' show ResultAvatar, ResultScaleToggle, resultScoreText;
import 'submission_detail_screen.dart' show FactGrid, ScoreBreakdown;

class AdminResultDetailScreen extends StatelessWidget {
  const AdminResultDetailScreen({super.key, required this.roundId, required this.contestantId});
  final String roundId;

  /// The app's local contestant id.
  final int contestantId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final result = admin.calculateRoundResults(roundId);
    void back() => AdminNav.round(context, AdminRoutes.roundResults, roundId);
    final item = result.available ? result.items.where((i) => i.contestantId == contestantId).firstOrNull : null;
    final percent = admin.resultsAsPercent;
    final rawMax = admin.rawMaxScore(roundId);

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.results,
      pageTitle: 'Result Detail',
      pageDescription: 'Contestant score and inclusion breakdown.',
      onBack: back,
      // API: per-judge criterion scores for this contestant.
      onLoad: (admin) => admin.loadResultDetail(roundId, contestantId),
      children: [
        if (!result.available)
          AdminStateCard(title: 'Results unavailable', description: result.reason)
        else if (item == null)
          const AdminStateCard(title: 'Contestant not found')
        else ...[
          Align(alignment: Alignment.centerLeft, child: BackLink('Results', onTap: back)),
          const SizedBox(height: 10),
          ResultScaleToggle(roundId: roundId),
          const SizedBox(height: 16),
          AdminPanel(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                ResultAvatar(item: item, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AdminEyebrow([item.numberLabel, if (item.profesi.isNotEmpty) item.profesi].join(' · ')),
                    const SizedBox(height: 7),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: item.name, style: ts(23, weight: FontWeight.w700)),
                      if (item.tied)
                        TextSpan(text: '  TIED', style: ts(12, weight: FontWeight.w700, color: AppColors.statusDraftColor)),
                    ])),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),
              FactGrid(facts: [
                ('Rank', '${item.rank}'),
                ('Combined Score', () {
                  final (value, outOf) = resultScoreText(item, percent: percent, rawMax: rawMax);
                  return '$value$outOf';
                }()),
                ('Eligible Judges', '${item.eligibleJudgeCount}'),
                ('Result status', result.finalized ? 'Finalized' : 'Provisional'),
              ]),
            ]),
          ),
          const AdminSectionHeading(
            title: 'Judge Breakdown',
            subtitle: 'Only Included scores contribute to the official combined score.',
          ),
          AdminPanel(
            child: Column(children: [
              for (final (i, j) in item.judgeScores.indexed)
                _JudgeRow(
                  entry: j,
                  first: i == 0,
                  percent: percent,
                  criteria: [for (final c in admin.scoredCriteria(roundId)) (c.id, c.name)],
                ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _JudgeRow extends StatefulWidget {
  const _JudgeRow({required this.entry, required this.first, required this.criteria, this.percent = true});
  final JudgeScoreEntry entry;
  final bool first;

  /// Judge total: weighted 0–100 (true) or the raw sum of criterion scores.
  final bool percent;
  final List<(String, String)> criteria;

  @override
  State<_JudgeRow> createState() => _JudgeRowState();
}

class _JudgeRowState extends State<_JudgeRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final j = widget.entry;
    final status = Text(j.included ? 'Included' : j.exclusion,
        style: ts(12,
            weight: j.included ? FontWeight.w700 : FontWeight.w400,
            color: j.included ? AppColors.success : AppColors.textSecondary));
    final shown = widget.percent ? j.total?.toStringAsFixed(2) : (j.rawTotal == null ? null : pct(j.rawTotal!));
    final total = Text(shown ?? '—', style: ts(14, weight: FontWeight.w700, tabular: true));
    final tiny = AdminLayout.tiny(context);
    return Container(
      decoration: BoxDecoration(border: widget.first ? null : Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: tiny
                ? Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(j.judgeNumber, style: ts(14, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        status,
                      ]),
                    ),
                    total,
                  ])
                : Row(children: [
                    Expanded(child: Text(j.judgeNumber, style: ts(14, weight: FontWeight.w700))),
                    const SizedBox(width: 14),
                    status,
                    const SizedBox(width: 14),
                    SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: total)),
                  ]),
          ),
        ),
        if (_open)
          ScoreBreakdown(rows: [
            for (final (id, name) in widget.criteria)
              (name, j.criteriaScores[id] == null ? '—' : j.criteriaScores[id]!.toStringAsFixed(2)),
          ]),
      ]),
    );
  }
}
