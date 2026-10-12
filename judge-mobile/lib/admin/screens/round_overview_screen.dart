// admin/round.html — Round Overview (admin-governance.js `renderRound`).

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';

class AdminRoundOverviewScreen extends StatelessWidget {
  const AdminRoundOverviewScreen({super.key, required this.roundId});
  final String roundId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final round = admin.getRound(roundId)!;
    final ready = admin.getRoundReadiness(roundId);
    final missing = ready.requiredJudges - ready.requiredSubmitted;
    final closed = round.status == 'closed';
    final finalized = round.status == 'finalized';
    final compact = AdminLayout.compact(context);

    final verdict = finalized
        ? 'Results finalized · scoring and configuration are locked'
        : closed
            ? 'Round closed · scoring is read-only'
            : ready.readyToClose
                ? '✓ Ready to close'
                : missing > 0
                    ? '$missing required judge${missing == 1 ? '' : 's'} still need attention'
                    : 'Round is not ready to close';

    final panels = [
      GovernancePanel(title: 'Judging readiness', children: [
        GovernanceCheck('${ready.contestantsAssigned > 0 ? '✓' : '○'} ${ready.contestantsAssigned} contestants assigned'),
        GovernanceCheck('${ready.judgesAssigned > 0 ? '✓' : '○'} ${ready.judgesAssigned} judges assigned'),
        GovernanceCheck('${ready.weightValid ? '✓' : '○'} Criteria weight = ${pct(ready.effectiveScoredWeight)}%'),
      ]),
      GovernancePanel(title: 'Submission readiness', children: [
        GovernanceCheck('${ready.requiredSubmitted} / ${ready.requiredJudges} required judges submitted'),
        GovernanceCheck('${ready.optionalJudges} optional judges do not block closing'),
        _Verdict(verdict, ready: ready.readyToClose),
      ]),
    ];

    Widget roundAction;
    if (finalized) {
      roundAction = AdminLockNote('', child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Official Results Ready · ', style: ts(12, color: AppColors.textSecondary)),
        AdminLink('View Results', onTap: () => AdminNav.round(context, AdminRoutes.roundResults, roundId)),
      ]));
    } else if (closed) {
      roundAction = AdminLockNote('', child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('This round is closed. ', style: ts(12, color: AppColors.textSecondary)),
        AdminLink('Review provisional results', onTap: () => AdminNav.round(context, AdminRoutes.roundResults, roundId)),
      ]));
    } else if (ready.readyToClose) {
      roundAction = Align(
        alignment: Alignment.centerLeft,
        child: AdminBtn('Close Round', variant: AdminBtnVariant.danger, onTap: () => _confirmClose(context)),
      );
    } else {
      roundAction = AdminWarning(
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Cannot close round yet. ', style: ts(13, weight: FontWeight.w700, color: AppColors.statusDraftColor)),
          Text(
            missing > 0
                ? '$missing required judge${missing == 1 ? ' has' : 's have'} not submitted. '
                : 'The round is not open or has no required judges. ',
            style: ts(13, weight: FontWeight.w600, color: AppColors.statusDraftColor),
          ),
          AdminLink('View Live Monitoring', onTap: () => AdminNav.round(context, AdminRoutes.monitoring, roundId)),
        ]),
      );
    }

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.overview,
      pageTitle: 'Overview',
      pageDescription: 'Round readiness and judging progress.',
      children: [
        AdminStatGrid([
          AdminStatCard(valueWidget: Align(alignment: Alignment.centerLeft, child: AdminStatus(round.status)), label: 'Round status'),
          AdminStatCard(value: '${ready.requiredSubmitted} / ${ready.requiredJudges}', label: 'Required submitted'),
          AdminStatCard(value: '${ready.optionalJudges}', label: 'Optional judges'),
          AdminStatCard(value: '${ready.contestantsAssigned}', label: 'Contestants assigned'),
        ]),
        compact
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [panels[0], const SizedBox(height: 16), panels[1]])
            : AdminGrid(columns: 2, children: panels),
        AdminSectionHeading(
          title: 'Round actions',
          subtitle: finalized
              ? 'Official result snapshot is locked.'
              : closed
                  ? 'Review provisional results before finalization.'
                  : 'Only required active judges block Close Round.',
        ),
        roundAction,
        const SizedBox(height: 20),
        Text('Lifecycle: Draft → Open → Closed → Finalized', style: ts(12, color: AppColors.textSecondary)),
        if (round.status == 'draft') ...[const SizedBox(height: 20), _NextRoundSetup(roundId: roundId)],
      ],
    );
  }

  void _confirmClose(BuildContext context) {
    final admin = AdminScope.read(context);
    final round = admin.getRound(roundId)!;
    showAdminModal(
      context,
      title: 'Close ${round.name}?',
      body: 'All required judges have submitted. Scoring will become read-only.',
      confirmLabel: 'Close Round',
      confirmVariant: AdminBtnVariant.danger,
      onConfirm: (_) => admin.closeRoundAction(roundId),
    );
  }
}

/// Draft round: advancement / judges / criteria checks + Configure, Copy, Open.
class _NextRoundSetup extends StatelessWidget {
  const _NextRoundSetup({required this.roundId});
  final String roundId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final round = admin.getRound(roundId)!;
    final ready = admin.getRoundReadiness(roundId);
    final previous = admin.getPreviousRound(roundId);
    final advancement = admin.getAdvancementForTarget(roundId);
    final canOpen = admin.canOpenRound(roundId);
    return GovernancePanel(
      eyebrow: 'Next round setup',
      title: '${round.name} readiness',
      children: [
        GovernanceCheck(advancement != null
            ? '✓ ${advancement.selectedContestantIds.length} contestants advanced from ${previous?.name ?? 'previous round'}'
            : previous == null
                ? '✓ First round · no advancement needed'
                : '○ Advancement from previous round pending'),
        GovernanceCheck(
            '${ready.judgesAssigned > 0 && ready.requiredJudges > 0 ? '✓' : '○'} ${ready.judgesAssigned} judges · ${ready.requiredJudges} Required'),
        GovernanceCheck('${ready.weightValid ? '✓' : '○'} Criteria ${pct(ready.effectiveScoredWeight)}% effective weight'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          AdminBtn('Configure Round', onTap: () => AdminNav.round(context, AdminRoutes.roundContestants, roundId)),
          if (previous != null && advancement != null)
            AdminBtn('Copy Configuration from ${previous.name}', onTap: () => _copy(context, previous.id, previous.name)),
          AdminBtn('Open ${round.name}', variant: AdminBtnVariant.primary, onTap: canOpen ? () => _open(context) : null),
        ]),
        if (!canOpen) ...[
          const SizedBox(height: 8),
          Text('Complete advancement and round readiness first.', style: ts(12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  void _open(BuildContext context) {
    final admin = AdminScope.read(context);
    final round = admin.getRound(roundId)!;
    final ready = admin.getRoundReadiness(roundId);
    showAdminModal(
      context,
      title: 'Open ${round.name}?',
      body: '${ready.contestantsAssigned} contestants · ${ready.judgesAssigned} judges · '
          '${pct(ready.effectiveScoredWeight)}% scoring weight. Judges will be able to begin scoring.',
      confirmLabel: 'Open Round',
      onConfirm: (_) => admin.openRoundAction(roundId),
    );
  }

  void _copy(BuildContext context, String sourceId, String sourceName) {
    final admin = AdminScope.read(context);
    var judges = true, criteria = true;
    showAdminModal(
      context,
      title: 'Copy configuration from $sourceName?',
      body: 'Contestants are not copied. The target gets independent configuration.',
      confirmLabel: 'Copy Configuration',
      extra: StatefulBuilder(
        builder: (context, setState) => Column(children: [
          _CheckRow('Judge assignments and Required flags', judges, (v) => setState(() => judges = v)),
          _CheckRow('Criteria hierarchy and scoring rules', criteria, (v) => setState(() => criteria = v)),
        ]),
      ),
      onConfirm: (_) => !judges && !criteria
          ? 'Choose at least one item to copy.'
          : admin.copyConfigurationAction(sourceId, roundId, judges: judges, criteria: criteria),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(children: [
          AdminCheckbox(value: value, onChanged: onChanged),
          Expanded(child: Text(label, style: ts(13, weight: FontWeight.w700))),
        ]),
      );
}

/// `.admin-governance-panel`
class GovernancePanel extends StatelessWidget {
  const GovernancePanel({super.key, required this.title, this.eyebrow, required this.children});
  final String title;
  final String? eyebrow;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AdminPanel(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (eyebrow != null) ...[AdminEyebrow(eyebrow!), const SizedBox(height: 7)],
          Text(title, style: ts(17, weight: FontWeight.w700)),
          const SizedBox(height: 15),
          ...children,
        ]),
      );
}

class GovernanceCheck extends StatelessWidget {
  const GovernanceCheck(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(text, style: ts(14, color: AppColors.textSecondary)));
}

class _Verdict extends StatelessWidget {
  const _Verdict(this.text, {required this.ready});
  final String text;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ready ? AdminColors.successTint : AppColors.statusDraftBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(text, style: ts(14, weight: FontWeight.w700, color: ready ? AppColors.success : AppColors.statusDraftColor)),
      );
}
