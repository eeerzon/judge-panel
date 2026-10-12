// Contestant Gallery — port of pages/contestants.html + contestants.js.
// Reachable any time. Once submitted: "Judging Submitted" banner, every card
// reads Scored, header CTA becomes "View Submission". No scores/ranking on
// cards (FR-7 privacy/fairness).

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../widgets/appearance_toggle.dart';
import '../widgets/common.dart';
import '../widgets/judge_chrome.dart';

enum _GalleryFilter { all, toScore, scored }

class ContestantsScreen extends StatefulWidget {
  const ContestantsScreen({super.key, required this.roundId});
  final String roundId;

  @override
  State<ContestantsScreen> createState() => _ContestantsScreenState();
}

class _ContestantsScreenState extends State<ContestantsScreen> {
  _GalleryFilter _filter = _GalleryFilter.all;

  @override
  Widget build(BuildContext context) {
    final store = JudgeScope.of(context);
    final roundId = widget.roundId;
    final round = store.getRound(roundId)!;
    final contestants = store.contestantsOf(roundId);
    final counts = store.countByStatus(roundId);
    final submitted = store.isSubmitted(roundId);

    final visible = contestants.where((c) {
      final status = store.getContestantStatus(roundId, c.id).status;
      return switch (_filter) {
        _GalleryFilter.all => true,
        _GalleryFilter.scored => status == ScoreStatus.scored,
        _GalleryFilter.toScore => status != ScoreStatus.scored,
      };
    }).toList();

    final ctaLabel = submitted
        ? 'View Submission'
        : (counts.scored == counts.total ? 'Review & Submit' : 'Review Progress');

    return JudgeBackHandler(
      onBack: () => JudgeNav.goToMyRounds(context),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: JudgeChrome(
            roundId: roundId,
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final portrait = constraints.maxHeight > width;
              final pad = portrait ? 20.0 : 40.0;
              final columns = portrait
                  ? 2
                  : width >= 1680
                      ? 5
                      : (width <= 1100 ? 3 : 4);
              final gap = portrait ? 16.0 : 20.0;
              final capWidth = width >= 1200 ? AppLayout.galleryMaxWidth : double.infinity;

              final filters = _FilterGroup(
                expand: portrait,
                filter: _filter,
                all: counts.total,
                toScore: counts.total - counts.scored,
                scored: counts.scored,
                onChanged: (f) => setState(() => _filter = f),
              );

              final header = MaxWidth(
                maxWidth: capWidth,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: portrait ? 20 : 22),
                      _GalleryHeader(
                        eventName: store.eventName(roundId),
                        portrait: portrait,
                        roundName: round.name,
                        ctaLabel: ctaLabel,
                        scored: counts.scored,
                        total: counts.total,
                        connection: store.connectionState,
                        onCta: () => JudgeNav.goToReview(context, roundId),
                      ),
                      if (submitted) ...[const SizedBox(height: 14), const _SubmittedBanner()],
                      const SizedBox(height: 14),
                      _ProgressBar(value: counts.total == 0 ? 0 : counts.scored / counts.total),
                      SizedBox(height: portrait ? 18 : 22),
                      if (portrait) ...[
                        const _GalleryTitle(),
                        const SizedBox(height: 14),
                        filters,
                      ] else
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 24,
                          runSpacing: 16,
                          children: [const _GalleryTitle(), filters],
                        ),
                      SizedBox(height: portrait ? 14 : 16),
                    ],
                  ),
                ),
              );

              final grid = MaxWidth(
                maxWidth: capWidth,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, portrait ? 32 : 40),
                  child: visible.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                          child: Text('No contestants in this filter.',
                              textAlign: TextAlign.center, style: ts(16, color: AppColors.textSecondary)),
                        )
                      : _CardGrid(
                          columns: columns,
                          gap: gap,
                          children: [
                            for (final c in visible)
                              _ContestantCard(
                                contestant: c,
                                info: store.getContestantStatus(roundId, c.id),
                                onTap: () => JudgeNav.goToScoring(context, roundId, c.id),
                              ),
                          ],
                        ),
                ),
              );

              // Tall enough (tablet): fixed header, only the grid scrolls, like
              // `.gallery-scroll`. Short screens: the header would eat the whole
              // viewport and leave the grid 0px tall, so everything scrolls.
              if (constraints.maxHeight < 640) {
                return SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, grid]),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, Expanded(child: SingleChildScrollView(child: grid))],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({
    required this.eventName,
    required this.portrait,
    required this.roundName,
    required this.ctaLabel,
    required this.scored,
    required this.total,
    required this.connection,
    required this.onCta,
  });

  /// The opened round's own event (a judge may have several events).
  final String eventName;
  final bool portrait;
  final String roundName;
  final String ctaLabel;
  final int scored;
  final int total;
  final ConnectionStateKind connection;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width <= 480;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Direct way back to the round list (same link as on Standby).
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: BackLink('My Rounds', onTap: () => JudgeNav.goToMyRounds(context)),
        ),
        Text(eventName, style: ts(small ? 18 : 22, weight: FontWeight.w700, letterSpacingEm: 0.01)),
        const SizedBox(height: 4),
        RoundLabel(roundName, color: AppColors.accent),
      ],
    );

    final judgeBlock = Column(
      crossAxisAlignment: portrait ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(SessionScope.of(context).judge?.identityLabel ?? '', style: ts(14, weight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '$scored / $total', style: ts(13, weight: FontWeight.w600, tabular: true)),
            const TextSpan(text: ' scored'),
          ]),
          style: ts(13, color: AppColors.textSecondary),
        ),
      ],
    );

    final actions = [
      AppButton(
        label: ctaLabel,
        onTap: onCta,
        padding: const EdgeInsets.symmetric(horizontal: 22),
      ),
    ];

    if (portrait) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [...actions, judgeBlock, ConnectionStatusView(state: connection), const AppearanceToggle()],
          ),
        ],
      );
    }

    // Right-hand controls wrap onto a second line instead of overflowing on
    // narrower landscape screens.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: left),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [...actions, judgeBlock, ConnectionStatusView(state: connection)],
          ),
        ),
        // Night / light mode at the far right of the header.
        const SizedBox(width: 20),
        const AppearanceToggle(),
      ],
    );
  }
}


class _SubmittedBanner extends StatelessWidget {
  const _SubmittedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: AppColors.statusScoredFill, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Dot(color: AppColors.statusScoredIcon),
        const SizedBox(width: 8),
        Text('Judging Submitted', style: ts(14, weight: FontWeight.w700, color: AppColors.statusScoredText)),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 4,
        color: AppColors.surfaceAlt,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 250),
          widthFactor: value.clamp(0, 1),
          heightFactor: 1,
          child: DecoratedBox(decoration: BoxDecoration(color: AppColors.accent)),
        ),
      ),
    );
  }
}

class _GalleryTitle extends StatelessWidget {
  const _GalleryTitle();

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width <= 480;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Contestants', style: ts(small ? 24 : 28, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Tap a contestant to enter scores.', style: ts(16, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.expand,
    required this.filter,
    required this.all,
    required this.toScore,
    required this.scored,
    required this.onChanged,
  });

  final bool expand;
  final _GalleryFilter filter;
  final int all;
  final int toScore;
  final int scored;
  final ValueChanged<_GalleryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final pills = [
      (_GalleryFilter.all, 'All', all),
      (_GalleryFilter.toScore, 'To Score', toScore),
      (_GalleryFilter.scored, 'Scored', scored),
    ];
    final children = <Widget>[];
    for (var i = 0; i < pills.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 10));
      final pill = FilterPill(
        label: pills[i].$2,
        count: pills[i].$3,
        active: filter == pills[i].$1,
        expand: expand,
        onTap: () => onChanged(pills[i].$1),
      );
      children.add(expand ? Expanded(child: pill) : pill);
    }
    return Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: children);
  }
}

/// CSS grid rows: each row as tall as its tallest card, cards stretch.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.columns, required this.gap, required this.children});
  final int columns;
  final double gap;
  final List<Widget> children;

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

/// `.contestant-card` — Photo → Number → Name → profesi → Status.
class _ContestantCard extends StatelessWidget {
  const _ContestantCard({required this.contestant, required this.info, required this.onTap});
  final Contestant contestant;
  final StatusInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.99,
      semanticLabel: '${contestant.numberLabel} ${contestant.name}, ${contestant.subtitle}, ${info.label}',
      child: ExcludeSemantics(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 3 / 4, child: ContestantPhoto(contestant: contestant)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contestant.numberLabel,
                        style: ts(20, weight: FontWeight.w700, color: AppColors.accent, letterSpacingEm: 0.02, tabular: true)),
                    const SizedBox(height: 4),
                    Text(contestant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts(18, weight: FontWeight.w600, height: 1.3)),
                    const SizedBox(height: 4),
                    Text(contestant.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts(14, weight: FontWeight.w500, color: AppColors.textSecondary, height: 1.3)),
                    const SizedBox(height: 12),
                    StatusChip(info: info),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
