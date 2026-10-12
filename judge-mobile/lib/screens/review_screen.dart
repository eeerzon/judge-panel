// Review & Submit — port of pages/review.html + review.js.
// Reachable any time, complete or not (it shows what is still missing).
// Opening it calls `POST .../review`; submitting calls `POST .../submit`
// through JudgeStore.submitJudging(), which re-checks completeness, flushes
// unsent scores first and reuses one idempotency key across retries.

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../state/judge_store.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/judge_chrome.dart';

enum _ReviewFilter { all, attention, scored }

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.roundId});
  final String roundId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;

  String get _roundId => widget.roundId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) JudgeScope.read(context).refreshReview(_roundId);
    });
  }

  void _goToFirstIncomplete(JudgeStore store) {
    final target = store.contestantsOf(_roundId)
        .where((c) => store.getContestantStatus(_roundId, c.id).status != ScoreStatus.scored)
        .firstOrNull;
    if (target != null) JudgeNav.goToScoring(context, _roundId, target.id, ScoringOrigin.review);
  }

  Future<void> _openSubmitModal(JudgeStore store) async {
    final round = store.getRound(_roundId)!;
    final submitted = await showDialog<bool>(
      context: context,
      barrierColor: const Color.fromRGBO(8, 4, 4, 0.72),
      builder: (_) => _SubmitDialog(store: store, round: round, total: store.countByStatus(_roundId).total),
    );
    if (submitted == true && mounted) JudgeNav.goToSubmitted(context, _roundId);
  }

  @override
  Widget build(BuildContext context) {
    final store = JudgeScope.of(context);
    final round = store.getRound(_roundId)!;
    final counts = store.countByStatus(_roundId);
    final submitted = store.isSubmitted(_roundId);
    final contestants = store.contestantsOf(_roundId);

    final visible = contestants.where((c) {
      final status = store.getContestantStatus(_roundId, c.id).status;
      return switch (_filter) {
        _ReviewFilter.all => true,
        _ReviewFilter.scored => status == ScoreStatus.scored,
        _ReviewFilter.attention => status != ScoreStatus.scored,
      };
    }).toList();

    return JudgeBackHandler(
      onBack: () => JudgeNav.goToContestants(context, _roundId),
      child: Scaffold(
        body: SafeArea(
          child: JudgeChrome(
            roundId: _roundId,
            child: LayoutBuilder(builder: (context, constraints) {
              final portrait = constraints.maxHeight > constraints.maxWidth;
              final hPad = portrait ? 20.0 : 32.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // .review-header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                    child: MaxWidth(
                      maxWidth: 1200,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: Row(children: [
                          AppButton(
                            label: '← Contestants',
                            onTap: () => JudgeNav.goToContestants(context, _roundId),
                            variant: AppButtonVariant.outline,
                            fontWeight: FontWeight.w500,
                          ),
                          const SizedBox(width: 16),
                          RoundLabel(round.name),
                        ]),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: MaxWidth(
                        maxWidth: 1100,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, portrait ? 24 : 32, hPad, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Review Your Judging', style: ts(portrait ? 22 : 26, weight: FontWeight.w700)),
                              const SizedBox(height: 20),
                              _SummaryPanel(counts: counts, submitted: submitted),
                              const SizedBox(height: 20),
                              _filters(counts, expand: portrait),
                              const SizedBox(height: 18),
                              if (visible.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                                  child: Text('No contestants in this filter.',
                                      textAlign: TextAlign.center, style: ts(16, color: AppColors.textSecondary)),
                                )
                              else
                                for (var i = 0; i < visible.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  _ReviewRow(
                                    contestant: visible[i],
                                    info: store.getContestantStatus(_roundId, visible[i].id),
                                    total: store.calculateContestantTotal(_roundId, visible[i].id),
                                    submitted: submitted,
                                    stacked: portrait,
                                    onTap: () =>
                                        JudgeNav.goToScoring(context, _roundId, visible[i].id, ScoringOrigin.review),
                                  ),
                                ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _ReviewFooter(
                    hPad: hPad,
                    counts: counts,
                    submitted: submitted,
                    onSubmit: () => _openSubmitModal(store),
                    onCompleteRemaining: () => _goToFirstIncomplete(store),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _filters(StatusCounts counts, {required bool expand}) {
    final pills = [
      (_ReviewFilter.all, 'All', counts.total),
      (_ReviewFilter.attention, 'Needs Attention', counts.draft + counts.notStarted),
      (_ReviewFilter.scored, 'Scored', counts.scored),
    ];
    final children = <Widget>[];
    for (var i = 0; i < pills.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 10));
      final pill = FilterPill(
        label: pills[i].$2,
        count: pills[i].$3,
        active: _filter == pills[i].$1,
        expand: expand,
        onTap: () => setState(() => _filter = pills[i].$1),
      );
      children.add(expand ? Expanded(child: pill) : pill);
    }
    return Row(children: children);
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.counts, required this.submitted});
  final StatusCounts counts;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    final allScored = counts.scored == counts.total;
    final ready = allScored && !submitted;
    final remaining = counts.total - counts.scored;
    final String note;
    if (submitted) {
      note = 'Judging submitted. These scores are locked and can no longer be edited.';
    } else if (allScored) {
      note = 'All contestants have been scored. Review your entries before submitting.';
    } else {
      note = '$remaining contestant${remaining == 1 ? '' : 's'} still need${remaining == 1 ? 's' : ''} attention. '
          'Complete all scores before final submission.';
    }
    final fraction = counts.total == 0 ? 0.0 : counts.scored / counts.total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ready ? AppColors.statusScoredFillBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${counts.scored} / ${counts.total} contestants scored',
              style: ts(20,
                  weight: FontWeight.w700,
                  color: ready ? AppColors.statusScoredOnPage : AppColors.textPrimary,
                  tabular: true)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              color: AppColors.surfaceAlt,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                heightFactor: 1,
                child: ColoredBox(color: ready ? AppColors.statusScoredFill : AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(note, style: ts(15, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _CountChip(kind: ScoreStatus.scored, label: '✓ Scored ${counts.scored}'),
            _CountChip(kind: ScoreStatus.draft, label: 'Draft ${counts.draft}'),
            _CountChip(kind: ScoreStatus.notStarted, label: 'Not Scored ${counts.notStarted}'),
          ]),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.kind, required this.label});
  final ScoreStatus kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, Color border, Color dot) = switch (kind) {
      ScoreStatus.scored => (
          AppColors.statusScoredText,
          AppColors.statusScoredFill,
          AppColors.statusScoredFillBorder,
          AppColors.statusScoredIcon
        ),
      ScoreStatus.draft => (
          AppColors.statusDraftColor,
          AppColors.statusDraftBg,
          AppColors.statusDraftBorder,
          AppColors.statusDraftColor
        ),
      ScoreStatus.notStarted => (AppColors.textSecondary, AppColors.surfaceAlt, AppColors.border, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Dot(color: dot),
        const SizedBox(width: 8),
        Text(label, style: ts(14, weight: FontWeight.w600, color: fg, tabular: true)),
      ]),
    );
  }
}

/// `.review-row` — Identity | Total Score | Action/Badge (140px columns).
/// Badge and action buttons share the same 120×48 box so rows never shift.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.contestant,
    required this.info,
    required this.total,
    required this.submitted,
    required this.stacked,
    required this.onTap,
  });

  final Contestant contestant;
  final StatusInfo info;
  final double? total;
  final bool submitted;
  final bool stacked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final identity = Row(children: [
      Container(
        width: 56,
        height: 56,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: ContestantPhoto(contestant: contestant, showInitials: false),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(contestant.numberLabel,
                    style: ts(15, weight: FontWeight.w700, color: AppColors.accent, tabular: true)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(contestant.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, weight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(contestant.subtitle,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, color: AppColors.textSecondary)),
            if (info.status != ScoreStatus.scored) ...[
              const SizedBox(height: 3),
              Text(
                info.label,
                style: ts(13,
                    weight: info.status == ScoreStatus.draft ? FontWeight.w600 : FontWeight.w500,
                    color: info.status == ScoreStatus.draft ? AppColors.statusDraftColor : AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    ]);

    final score = Column(
      crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TOTAL SCORE',
            style: ts(11, weight: FontWeight.w600, color: AppColors.textSecondary, letterSpacingEm: 0.12)),
        const SizedBox(height: 2),
        Text(
          total == null ? '—' : total!.toStringAsFixed(2),
          style: ts(22,
              weight: total == null ? FontWeight.w500 : FontWeight.w700,
              color: total == null ? AppColors.textSecondary : AppColors.textPrimary,
              height: 1.2,
              tabular: true),
        ),
        const SizedBox(height: 2),
        Text('/ 100', style: ts(12, color: AppColors.textSecondary)),
      ],
    );

    final Widget action;
    if (info.status == ScoreStatus.scored) {
      action = _rowBox(
        stacked: stacked,
        bg: AppColors.statusScoredFill,
        border: AppColors.statusScoredFillBorder,
        glow: true,
        child: Text('✓ Scored', style: ts(14, weight: FontWeight.w700, color: AppColors.statusScoredText)),
      );
    } else if (submitted) {
      action = const SizedBox.shrink();
    } else {
      action = _rowBox(
        stacked: stacked,
        bg: AppColors.surfaceAlt,
        border: AppColors.accentDeep,
        child: Text(info.status == ScoreStatus.draft ? 'Continue' : 'Score',
            style: ts(14, weight: FontWeight.w600)),
      );
    }

    return Pressable(
      onTap: onTap,
      pressedScale: 0.99,
      semanticLabel: '${contestant.numberLabel} ${contestant.name}, ${contestant.subtitle}, ${info.label}',
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minHeight: stacked ? 0 : 88),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, const SizedBox(height: 14), score, const SizedBox(height: 14), action],
                )
              : Row(children: [
                  Expanded(child: identity),
                  const SizedBox(width: 24),
                  SizedBox(width: 140, child: score),
                  const SizedBox(width: 24),
                  SizedBox(width: 140, child: Center(child: action)),
                ]),
        ),
      ),
    );
  }

  static Widget _rowBox({
    required bool stacked,
    required Color bg,
    required Color border,
    required Widget child,
    bool glow = false,
  }) {
    return Container(
      width: stacked ? double.infinity : 120,
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        boxShadow: glow ? const [BoxShadow(color: AppColors.statusScoredGlow, blurRadius: 10)] : null,
      ),
      child: child,
    );
  }
}

class _ReviewFooter extends StatelessWidget {
  const _ReviewFooter({
    required this.hPad,
    required this.counts,
    required this.submitted,
    required this.onSubmit,
    required this.onCompleteRemaining,
  });

  final double hPad;
  final StatusCounts counts;
  final bool submitted;
  final VoidCallback onSubmit;
  final VoidCallback onCompleteRemaining;

  @override
  Widget build(BuildContext context) {
    final allScored = counts.scored == counts.total;
    final remaining = counts.total - counts.scored;

    Widget content;
    if (submitted) {
      content = Text('Judging submitted — scores are locked.',
          textAlign: TextAlign.center, style: ts(13, color: AppColors.textSecondary));
    } else {
      content = Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                allScored
                    ? '${counts.total} / ${counts.total} completed'
                    : '$remaining contestant${remaining == 1 ? '' : 's'} remaining',
                style: ts(15, weight: FontWeight.w700, tabular: true),
              ),
              const SizedBox(height: 2),
              Text(allScored ? '✓ Ready to submit' : 'Complete all contestants before submitting.',
                  style: ts(13, color: AppColors.textSecondary)),
            ],
          ),
          AppButton(
            label: allScored ? 'Submit Judging' : 'Complete Remaining Scores',
            onTap: allScored ? onSubmit : onCompleteRemaining,
            variant: allScored ? AppButtonVariant.ready : AppButtonVariant.primary,
            height: 56,
            radius: 12,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            padding: const EdgeInsets.symmetric(horizontal: 32),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.28), blurRadius: 24, offset: Offset(0, -8))],
      ),
      child: MaxWidth(
        maxWidth: 1100,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
          child: SizedBox(width: double.infinity, child: content),
        ),
      ),
    );
  }
}

enum _ModalState { confirm, submitting, failed }

/// `.modal-panel` — confirm body and failed body are mutually exclusive.
class _SubmitDialog extends StatefulWidget {
  const _SubmitDialog({required this.store, required this.round, required this.total});
  final JudgeStore store;
  final Round round;
  final int total;

  @override
  State<_SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<_SubmitDialog> {
  _ModalState _state = _ModalState.confirm;
  String? _failure;

  Future<void> _attemptSubmit() async {
    setState(() => _state = _ModalState.submitting);
    final error = await widget.store.submitJudging(widget.round.id); // re-checks completeness
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _state = _ModalState.failed;
        _failure = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _state == _ModalState.submitting;
    final failed = _state == _ModalState.failed;

    Widget modalButton(String label, VoidCallback? onTap, {required bool primary}) => AppButton(
          label: label,
          onTap: onTap,
          variant: primary ? AppButtonVariant.primary : AppButtonVariant.outline,
          height: 52,
          radius: 12,
          fontSize: 15,
          disabledOpacity: 0.6,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        );

    return PopScope(
      canPop: !busy,
      child: Dialog(
        backgroundColor: AppColors.surfaceRaised,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.borderStrong),
        ),
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: failed
                  ? [
                      Text('Submission failed',
                          style: ts(22, weight: FontWeight.w700, color: AppColors.statusErrorColor)),
                      const SizedBox(height: 14),
                      Text('Your scores are still safe. Please try again.', style: ts(16, height: 1.5)),
                      if (_failure != null) ...[
                        const SizedBox(height: 10),
                        Text(_failure!, style: ts(15, color: AppColors.textSecondary, height: 1.5)),
                      ],
                      const SizedBox(height: 24 + 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          modalButton('Close', () => Navigator.of(context).pop(false), primary: false),
                          const SizedBox(width: 12),
                          modalButton('Try Again', _attemptSubmit, primary: true),
                        ],
                      ),
                    ]
                  : [
                      Text('Submit ${widget.round.name} Judging?', style: ts(22, weight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Text('You have scored all ${widget.total} contestants.', style: ts(16, height: 1.5)),
                      const SizedBox(height: 12),
                      Text('After submitting, your scores will be locked and can no longer be changed.',
                          style: ts(15, color: AppColors.textSecondary, height: 1.5)),
                      const SizedBox(height: 24 + 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          modalButton('Cancel', busy ? null : () => Navigator.of(context).pop(false), primary: false),
                          const SizedBox(width: 12),
                          modalButton(busy ? 'Submitting…' : 'Submit Scores', busy ? null : _attemptSubmit,
                              primary: true),
                        ],
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
