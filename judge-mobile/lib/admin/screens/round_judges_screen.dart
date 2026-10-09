// admin/round-judges.html — judge assignment + Required (admin-round-config.js
// `judgeContent`). Editable only while the round is Draft.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_scope.dart';
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';
import 'round_contestants_screen.dart' show ConfigLockNote, ReadinessSummary;

class AdminRoundJudgesScreen extends StatelessWidget {
  const AdminRoundJudgesScreen({super.key, required this.roundId});
  final int roundId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final round = admin.getRound(roundId)!;
    final locked = round.status != 'draft';
    final assignments = admin.getRoundJudges(roundId);
    // Inactive master judges cannot be assigned; one already assigned stays
    // listed so it can still be unassigned.
    final judges = [
      for (final j in admin.judges)
        if (j.active || assignments.any((e) => e.$1.judgeId == j.id && e.$1.status != 'unassigned')) j,
    ];
    final compact = AdminLayout.compact(context);
    final tiny = AdminLayout.tiny(context);

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.judges,
      pageTitle: 'Judges',
      pageDescription: 'Assign event judges and mark required participation.',
      children: [
        ConfigLockNote(locked: locked),
        ReadinessSummary(store: admin, roundId: roundId),
        AdminPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 14,
                runSpacing: 6,
                children: [
                  Text('Round judge assignments', style: ts(14, weight: FontWeight.w700)),
                  Text('Required status applies only to assigned judges.', style: ts(12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                if (judges.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('No active judges. Activate or add judges in Judges first.',
                        style: ts(13, color: AppColors.textSecondary)),
                  ),
                for (final (i, judge) in judges.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  () {
                    final assignment = assignments.where((e) => e.$1.judgeId == judge.id).firstOrNull?.$1;
                    final state = assignment?.status ?? 'unassigned';
                    final isAssigned = state == 'assigned';
                    final required = assignment?.required ?? false;
                    final person = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Judge ${judge.displayNumber} · ${judge.name}', style: ts(14, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text([judge.email, judge.phone].where((t) => t.trim().isNotEmpty).join(' · '),
                          style: ts(12, color: AppColors.textSecondary)),
                      if (!judge.active) ...[
                        const SizedBox(height: 4),
                        Text('Inactive in Judges · unassign or reactivate',
                            style: ts(12, weight: FontWeight.w600, color: AppColors.statusDraftColor)),
                      ],
                    ]);
                    final assignToggle = _CheckLabel(
                      label: 'Assigned',
                      value: isAssigned,
                      onChanged: locked
                          ? null
                          : (v) => _adminSnack(context, admin.setJudgeAssignmentAction(roundId, judge.id, v)),
                    );
                    final requiredToggle = _CheckLabel(
                      label: required ? 'Required' : 'Optional',
                      value: required,
                      onChanged: locked || !isAssigned
                          ? null
                          : (v) => _adminSnack(context, admin.setJudgeRequiredAction(roundId, judge.id, v)),
                    );
                    final status = AdminStatus(isAssigned ? 'assigned' : state);
                    return Container(
                      constraints: const BoxConstraints(minHeight: 76),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: compact
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              person,
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 14,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: tiny ? [assignToggle, requiredToggle, status] : [status, assignToggle, requiredToggle],
                              ),
                            ])
                          : Row(children: [
                              Expanded(child: person),
                              const SizedBox(width: 14),
                              assignToggle,
                              const SizedBox(width: 14),
                              requiredToggle,
                              const SizedBox(width: 14),
                              status,
                            ]),
                    );
                  }(),
                ],
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}

/// `.admin-required-toggle` — checkbox + label.
class _CheckLabel extends StatelessWidget {
  const _CheckLabel({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Opacity(
          opacity: onChanged == null ? 0.6 : 1,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AdminCheckbox(value: value, onChanged: onChanged),
            Text(label, style: ts(12, weight: FontWeight.w700)),
          ]),
        ),
      );
}

/// Runs an Admin action and shows its error, if any.
Future<void> _adminSnack(BuildContext context, Future<String?> action) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await action;
  if (error == null) return;
  messenger.showSnackBar(SnackBar(
    backgroundColor: AppColors.surfaceRaised,
    content: Text(error, style: ts(14)),
  ));
}
