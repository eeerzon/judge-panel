// Judge root — port of pages/my-rounds.html + my-rounds.js, fed by
// `GET /judge/rounds` (only rounds assigned to this judge are returned).

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../state/judge_store.dart';
import '../theme/tokens.dart';
import '../widgets/appearance_toggle.dart';
import '../widgets/common.dart';

class MyRoundsScreen extends StatefulWidget {
  const MyRoundsScreen({super.key});

  @override
  State<MyRoundsScreen> createState() => _MyRoundsScreenState();
}

class _MyRoundsScreenState extends State<MyRoundsScreen> {
  @override
  void initState() {
    super.initState();
    // Always refresh: round status / submission may have changed on the server.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) JudgeScope.read(context).refreshRoundsIfStale();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final store = JudgeScope.of(context);
    final judge = session.judge;
    final rounds = store.rounds;

    return JudgeBackHandler(
      onBack: () => JudgeNav.goToModeSelector(context),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width <= 620 ? 1 : (width <= 900 ? 2 : 3);
            final sidePad = width <= 620 ? 14.0 : 20.0;
            final topPad = (width * 0.08).clamp(42.0, 96.0);

            final Widget body;
            if (rounds == null && store.roundsError == null) {
              body = const _Notice(title: 'Loading your rounds…', loading: true);
            } else if (rounds == null) {
              body = _Notice(
                title: "Couldn't load your rounds",
                message: store.roundsError!.message,
                action: AppButton(label: 'Try Again', onTap: store.loadRounds, fontWeight: FontWeight.w700),
              );
            } else if (rounds.isEmpty) {
              body = const _Notice(
                title: 'No rounds assigned yet',
                message: 'You will see a round here once an admin assigns you to it. Pull down to refresh.',
              );
            } else {
              // One section per event (a judge can be assigned in several):
              // the event name is the section title, its rounds below.
              final groups = <String, List<Round>>{};
              for (final r in rounds) {
                groups.putIfAbsent(r.eventId ?? r.eventName ?? '', () => []).add(r);
              }
              body = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, group) in groups.values.indexed) ...[
                    if (i > 0) const SizedBox(height: 36),
                    _EventTitle(
                      name: group.first.eventName ?? 'Event',
                      year: (group.first.openedAt ?? group.first.createdAt ?? DateTime.now()).year,
                    ),
                    const SizedBox(height: 16),
                    _Grid(
                      columns: columns,
                      children: [for (final r in group) _RoundCard(model: _RoundCardModel.from(store, r))],
                    ),
                  ],
                ],
              );
            }

            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surfaceRaised,
              onRefresh: store.loadRounds,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(sidePad, width <= 620 ? 36 : topPad, sidePad, 64),
                child: MaxWidth(
                  maxWidth: 1040,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: _Header(
                                accountLabel: judge?.email ?? 'Judge',
                                name: judge?.name ?? '',
                                onLogout: () => SessionScope.read(context).logout(),
                              ),
                            ),
                          ),
                        ),
                        // Night / light mode at the right edge of the content.
                        const SizedBox(width: 16),
                        const AppearanceToggle(),
                      ]),
                      const SizedBox(height: 34),
                      body,
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, this.message, this.action, this.loading = false});
  final String title;
  final String? message;
  final Widget? action;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (loading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(child: Text(title, style: ts(20, weight: FontWeight.w700))),
        ]),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(message!, style: ts(15, color: AppColors.textSecondary, height: 1.5)),
        ],
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.accountLabel, required this.name, required this.onLogout});
  final String accountLabel;
  final String name;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // .judge-account-bar
        Text(accountLabel, style: ts(12, weight: FontWeight.w700, color: AppColors.textSecondary, letterSpacingEm: 0.04)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          if (SessionScope.of(context).canAdmin) AppButton(
            label: 'Switch to Admin Mode',
            onTap: () => JudgeNav.goToAdmin(context),
            height: 42,
            radius: 10,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _GhostButton(label: 'Log Out', onTap: onLogout),
        ]),
        const SizedBox(height: 30),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Good evening,\n'),
            TextSpan(text: name, style: ts(20, weight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          style: ts(20, color: AppColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 10),
        Text('Choose an assigned round to begin or continue judging.',
            style: ts(15, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Event section title — takes the place of the former "MY ROUNDS"
/// heading; the year sits under it (was the header eyebrow).
class _EventTitle extends StatelessWidget {
  const _EventTitle({required this.name, required this.year});
  final String name;
  final int year;

  @override
  Widget build(BuildContext context) {
    // Compact so the round cards below stay in view.
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name.toUpperCase(), style: ts(22, weight: FontWeight.w700, letterSpacingEm: -0.01)),
      const SizedBox(height: 4),
      Text('$year', style: ts(13, color: AppColors.textSecondary)),
    ]);
  }
}

/// `.judge-btn-ghost`
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.transparent),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(label, style: ts(14, weight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(i, (i + columns).clamp(0, children.length));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) const SizedBox(width: gap),
              Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
            ],
          ],
        ),
      ));
      if (i + columns < children.length) rows.add(const SizedBox(height: gap));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

enum _CardAction { enter, continueJudging, viewSubmission, viewResults }

class _RoundCardModel {
  const _RoundCardModel({
    required this.round,
    required this.label,
    required this.detail,
    required this.actions,
    required this.muted,
    required this.contestantCount,
  });

  final Round round;
  final String label;
  final String detail;
  final List<(_CardAction, String, bool secondary)> actions;
  final bool muted;
  final int? contestantCount;

  /// Same decision order as my-rounds.js `card(round)`. Every round from
  /// the API is assigned to this judge; progress needs the round's sheet,
  /// which JudgeStore loads in the background after the list arrives.
  factory _RoundCardModel.from(JudgeStore store, Round round) {
    final loaded = store.data(round.id) != null;
    final submitted = loaded && store.isSubmitted(round.id);
    final counts = store.countByStatus(round.id);
    final at = store.submittedAt(round.id);

    var label = 'Not Available';
    var detail = 'Round not open yet';
    var actions = <(_CardAction, String, bool)>[];

    if (round.status == RoundStatus.finalized) {
      label = '✓ Completed';
      detail = round.resultsVisibleToJudges ? 'Results Available' : 'Results hidden';
      actions = [
        if (round.resultsVisibleToJudges) (_CardAction.viewResults, 'View Results', false),
        if (submitted) (_CardAction.viewSubmission, 'View Submission', true),
      ];
    } else if (round.status == RoundStatus.closed) {
      label = submitted ? 'Closed · Submitted' : 'Closed';
      detail = 'Scoring is read-only';
      if (submitted) actions = [(_CardAction.viewSubmission, 'View Submission', false)];
    } else if (submitted) {
      label = '✓ Submitted';
      detail = '${counts.scored} / ${counts.total} scored${at != null ? ' · Submitted at ${formatClock(at.toLocal())}' : ''}';
      actions = [(_CardAction.viewSubmission, 'View Submission', false)];
    } else if (round.status == RoundStatus.open && loaded && store.isReopened(round.id)) {
      label = 'Submission Reopened';
      detail = 'Correction requested by Head Judge';
      actions = [(_CardAction.continueJudging, 'Continue Judging', false)];
    } else if (round.status == RoundStatus.open && counts.scored > 0) {
      label = 'In Progress';
      detail = '${counts.scored} / ${counts.total} scored';
      actions = [(_CardAction.continueJudging, 'Continue Judging', false)];
    } else if (round.status == RoundStatus.open) {
      label = 'Open';
      detail = loaded ? 'Ready to judge · ${counts.total} contestants' : 'Ready to judge';
      actions = [(_CardAction.enter, 'Enter Round', false)];
    }

    return _RoundCardModel(
      round: round,
      label: label,
      detail: detail,
      actions: actions,
      muted: label == 'Not Available',
      contestantCount: loaded ? counts.total : null,
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.model});
  final _RoundCardModel model;

  void _handle(BuildContext context, _CardAction action) {
    final id = model.round.id;
    switch (action) {
      case _CardAction.viewResults:
        JudgeNav.goToResults(context, id);
      case _CardAction.viewSubmission:
        JudgeNav.goToSubmitted(context, id);
      case _CardAction.enter:
      case _CardAction.continueJudging:
        // Standby is hidden: straight to the gallery (a spinner while loading).
        JudgeNav.goToContestants(context, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = model.round;
    // Each card in its own event's theme (My Rounds may mix events).
    final palette = JudgeThemeScope.of(context).themeFor(round.eventId)?.paletteFor(light: AppColors.light) ?? AppColors.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: 242),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('${twoDigits(round.orderNo)} · ROUND',
                    style: ts(11, weight: FontWeight.w700, color: palette.accent, letterSpacingEm: 0.14)),
              ),
              const SizedBox(width: 12),
              Text(
                model.label,
                style: ts(12, weight: FontWeight.w700, color: model.muted ? AppColors.textSecondary : AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(round.name, style: ts(24, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(model.contestantCount == null ? 'Contestants —' : '${model.contestantCount} Contestants',
              style: ts(15, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Text(model.detail, style: ts(13, color: AppColors.textSecondary, height: 1.5)),
          ),
          const SizedBox(height: 22),
          const Spacer(),
          if (model.actions.isEmpty)
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.all(14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text('Unavailable', style: ts(13, color: AppColors.textSecondary)),
            )
          else
            for (var i = 0; i < model.actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              AppButton(
                palette: palette,
                label: model.actions[i].$2,
                variant: model.actions[i].$3 ? AppButtonVariant.neutral : AppButtonVariant.primary,
                expand: true,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                onTap: () => _handle(context, model.actions[i].$1),
              ),
            ],
        ],
      ),
    );
  }
}
