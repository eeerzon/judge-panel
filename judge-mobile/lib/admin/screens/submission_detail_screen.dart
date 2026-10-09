// admin/submission-detail.html — one judge's sheet (admin-governance.js
// `renderSubmission`). Scores are prototype reference data (no Admin API).

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import '../../widgets/common.dart' show BackLink;
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';
import 'round_overview_screen.dart' show GovernancePanel;

class AdminSubmissionScreen extends StatelessWidget {
  const AdminSubmissionScreen({super.key, required this.roundId, required this.judgeId});
  final int roundId, judgeId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final round = admin.getRound(roundId)!;
    final judge = admin.getMonitoringJudges(roundId).where((j) => j.id == judgeId).firstOrNull;
    void back() => AdminNav.round(context, AdminRoutes.monitoring, roundId);

    if (judge == null) {
      return RoundWorkspace(
        roundId: roundId,
        activeTab: RoundTab.monitoring,
        pageTitle: 'Submission Detail',
        onBack: back,
        children: [
          const GovernancePanel(title: 'Submission not found', children: [Text('Return to Monitoring and choose a judge.')]),
        ],
      );
    }

    final history = admin.getReopens(roundId).where((r) => r.judgeId == judgeId).toList();
    final original = history.isNotEmpty ? history.first.originalSubmittedAt ?? judge.submittedAt : judge.submittedAt;
    final timeline = <(String, String)>[
      if (original != null) (adminTime(original), 'Original submission'),
      for (final r in history) ...[
        (adminTime(r.reopenedAt), 'Reopened · ${r.reason}'),
        if (r.resubmittedAt != null) (adminTime(r.resubmittedAt), 'Resubmitted'),
      ],
    ];
    final facts = [
      ('Round', round.name),
      ('Submitted at', adminTime(judge.submittedAt)),
      ('Progress', '${judge.completed} / ${judge.total} contestants'),
      ('Connection', judge.connection == 'offline' ? 'Offline' : 'Synced'),
    ];

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.monitoring,
      pageTitle: 'Submission Detail',
      pageDescription: 'Admin-only score and submission review.',
      onBack: back,
      children: [
        Align(alignment: Alignment.centerLeft, child: BackLink('Monitoring', onTap: back)),
        const SizedBox(height: 10),
        AdminPanel(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AdminEyebrow(judge.number),
                  const SizedBox(height: 7),
                  Text(judge.name, style: ts(22, weight: FontWeight.w700)),
                ]),
              ),
              AdminStatus(judge.submissionStatus),
            ]),
            const SizedBox(height: 20),
            FactGrid(facts: facts),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Submission history', style: ts(14, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final (time, text) in timeline)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 60, child: Text(time, style: ts(13, weight: FontWeight.w700))),
                        Expanded(child: Text(text, style: ts(13, color: AppColors.textSecondary))),
                      ]),
                    ),
                ]),
              ),
            ],
          ]),
        ),
        const AdminSectionHeading(
          title: 'Contestant scores',
          subtitle:
              'Open a contestant to inspect criteria. Prototype reference data is used until the Admin API provides judge score sheets.',
        ),
        AdminPanel(
          child: Column(children: [
            for (final (i, c) in admin.getRoundContestants(roundId).indexed)
              _ScoreRow(store: admin, roundId: roundId, judge: judge, contestant: c, first: i == 0),
          ]),
        ),
      ],
    );
  }
}

/// `.admin-submission-facts` (4 columns, 2 on compact).
class FactGrid extends StatelessWidget {
  const FactGrid({super.key, required this.facts});
  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final cells = [
      for (final (label, value) in facts)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(9)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: ts(12, color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            Text(value, style: ts(14, weight: FontWeight.w700)),
          ]),
        ),
    ];
    return AdminGrid(columns: AdminLayout.compact(context) ? 2 : 4, gap: AdminLayout.tiny(context) ? 8 : 14, children: cells);
  }
}

class _ScoreRow extends StatefulWidget {
  const _ScoreRow({required this.store, required this.roundId, required this.judge, required this.contestant, required this.first});
  final AdminStore store;
  final int roundId;
  final MonitoringJudge judge;
  final ContestantMaster contestant;
  final bool first;

  @override
  State<_ScoreRow> createState() => _ScoreRowState();
}

class _ScoreRowState extends State<_ScoreRow> {
  bool _open = false;
  bool _loading = false;

  /// API: scores come from `GET rounds/{id}/results/{rc}` (closed/finalized
  /// rounds only), loaded when the row is opened.
  Future<void> _toggle() async {
    setState(() => _open = !_open);
    final s = widget.store;
    final round = s.getRound(widget.roundId);
    if (!s.connected || !_open || _loading || round == null || round.status == 'draft' || round.status == 'open') return;
    if (s.judgeScoreEntry(widget.roundId, widget.judge.id, widget.contestant.id) != null) return;
    setState(() => _loading = true);
    await s.loadResultDetail(widget.roundId, widget.contestant.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store, j = widget.judge, c = widget.contestant;
    final double? total;
    final Map<String, double> sheet;
    if (s.connected) {
      final entry = s.judgeScoreEntry(widget.roundId, j.id, c.id);
      total = entry?.total;
      sheet = entry?.criteriaScores ?? const {};
    } else {
      final hasTotal = j.completed >= c.number || ['submitted', 'resubmitted', 'reopened'].contains(j.submissionStatus);
      total = hasTotal ? s.calculateContestantJudgeTotal(widget.roundId, j.id, c.id) : null;
      sheet = s.getJudgeScoreSheet(widget.roundId, j.id, c.id);
    }
    final roundOpen = s.connected && ['draft', 'open'].contains(s.getRound(widget.roundId)?.status);
    final tiny = AdminLayout.tiny(context);
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${c.numberLabel} ${c.name}', style: ts(14, weight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(c.profesi, style: ts(12, color: AppColors.textSecondary)),
    ]);
    final score = Text.rich(TextSpan(children: [
      TextSpan(text: 'Total Score  ', style: ts(12, color: AppColors.textSecondary)),
      TextSpan(text: total == null ? '—' : total.toStringAsFixed(2), style: ts(15, weight: FontWeight.w700, tabular: true)),
    ]));
    return Container(
      decoration: BoxDecoration(border: widget.first ? null : Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: _toggle,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: tiny
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 8), score])
                : Row(children: [Expanded(child: title), const SizedBox(width: 12), score]),
          ),
        ),
        if (_open && roundOpen)
          const ScoreBreakdown(rows: [('Scores are available after the round is closed.', '')])
        else if (_open && _loading)
          const ScoreBreakdown(rows: [('Loading scores…', '')])
        else if (_open)
          ScoreBreakdown(
            rows: [
              for (final cr in s.scoredCriteria(widget.roundId))
                (cr.name, total == null || sheet[cr.id] == null ? '—' : sheet[cr.id]!.toStringAsFixed(2)),
            ],
            total: total == null ? '—' : '${total.toStringAsFixed(2)} / 100',
          ),
      ]),
    );
  }
}

/// `.admin-score-detail` (criteria list + TOTAL).
class ScoreBreakdown extends StatelessWidget {
  const ScoreBreakdown({super.key, required this.rows, this.total});
  final List<(String, String)> rows;
  final String? total;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surfaceAlt,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        child: Column(children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(child: Text(label, style: ts(13, color: AppColors.textSecondary))),
                Text(value, style: ts(13, weight: FontWeight.w700, tabular: true)),
              ]),
            ),
          if (total != null)
            Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderStrong))),
              child: Row(children: [
                Expanded(child: Text('TOTAL', style: ts(13, weight: FontWeight.w800))),
                Text(total!, style: ts(13, weight: FontWeight.w800, tabular: true)),
              ]),
            ),
        ]),
      );
}
