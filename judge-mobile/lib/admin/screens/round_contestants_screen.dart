// admin/round-contestants.html — round participation (admin-round-config.js
// `contestantContent`). Editable only while the round is Draft.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';

class AdminRoundContestantsScreen extends StatefulWidget {
  const AdminRoundContestantsScreen({super.key, required this.roundId});
  final int roundId;

  @override
  State<AdminRoundContestantsScreen> createState() => _State();
}

class _State extends State<AdminRoundContestantsScreen> {
  final Set<int> _selected = {};
  String _term = '';

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final roundId = widget.roundId;
    final round = admin.getRound(roundId)!;
    final locked = round.status != 'draft';
    final all = admin.contestants;
    final assignedIds = admin.getRoundContestants(roundId).map((c) => c.id).toSet();
    final advancement = admin.getAdvancementForTarget(roundId);
    final source = advancement == null ? null : admin.getRound(advancement.sourceRoundId);
    final differs = advancement != null &&
        (assignedIds.length != advancement.selectedContestantIds.length ||
            assignedIds.any((id) => !advancement.selectedContestantIds.contains(id)));
    final list = all
        .where((c) => '${c.number} ${c.name} ${c.profesi}'.toLowerCase().contains(_term.toLowerCase()))
        .toList();
    final compact = AdminLayout.compact(context);

    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      AdminBtn('Select All', small: true, onTap: locked ? null : () => setState(() => _selected.addAll(list.map((c) => c.id)))),
      AdminBtn('Clear Selection', small: true, onTap: locked ? null : () => setState(_selected.clear)),
      AdminBtn('Add Selected', small: true, variant: AdminBtnVariant.primary, onTap: locked ? null : () => _apply(admin, add: true)),
      AdminBtn('Remove Selected', small: true, variant: AdminBtnVariant.danger, onTap: locked ? null : () => _apply(admin, add: false)),
    ]);

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.contestants,
      pageTitle: 'Contestants',
      pageDescription: 'Choose which event contestants participate in this round.',
      children: [
        ConfigLockNote(locked: locked),
        if (advancement != null) ...[
          AdminLockNote(
              'Source: Advanced from ${source?.name}. Any Draft-round adjustment requires a reason; the official source result stays unchanged.'),
          if (differs) ...[
            const AdminWarning(
                child: Text('Current contestant assignment differs from confirmed advancement. Adjustment reasons are retained in history.')),
            const SizedBox(height: 16),
          ],
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${assignedIds.length} of ${all.length}', style: ts(13, weight: FontWeight.w700)),
            const TextSpan(text: ' assigned'),
          ]), style: ts(13, color: AppColors.textSecondary)),
        ),
        ReadinessSummary(store: admin, roundId: roundId),
        AdminPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: compact
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      AdminSearchField(hint: 'Search number, name', onChanged: (t) => setState(() => _term = t)),
                      const SizedBox(height: 14),
                      actions,
                    ])
                  : Row(children: [
                      Expanded(
                          child: AdminSearchField(
                              hint: 'Search number, name', onChanged: (t) => setState(() => _term = t))),
                      const SizedBox(width: 14),
                      Flexible(child: Align(alignment: Alignment.centerRight, child: actions)),
                    ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                for (final (i, c) in list.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _AssignmentCard(
                    contestant: c,
                    assigned: assignedIds.contains(c.id),
                    selected: _selected.contains(c.id),
                    onSelect: locked
                        ? null
                        : (v) => setState(() => v ? _selected.add(c.id) : _selected.remove(c.id)),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  void _apply(AdminStore admin, {required bool add}) {
    final roundId = widget.roundId;
    final before = admin.getRoundContestants(roundId).map((c) => c.id).toList();
    var ids = before;
    for (final id in _selected) {
      ids = add ? (ids.contains(id) ? ids : [...ids, id]) : ids.where((e) => e != id).toList();
    }
    // Feedback: how many actually changed (already-assigned ones are skipped).
    final changed = add ? ids.where((id) => !before.contains(id)).length : before.where((id) => !ids.contains(id)).length;
    final roundName = admin.getRound(roundId)?.name ?? 'this round';
    final noun = changed == 1 ? 'contestant' : 'contestants';
    final message = changed == 0
        ? (add ? 'The selected contestants are already in $roundName.' : 'None of the selected contestants are in $roundName.')
        : add
            ? '$changed $noun added to $roundName.'
            : '$changed $noun removed from $roundName.';
    void notify(String text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar() // the latest result replaces an older message
        ..showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceRaised,
        content: Text(text, style: ts(14)),
      ));
    }

    if (_selected.isEmpty) return notify('Select contestants first.');
    if (changed == 0) return notify(message);
    if (admin.getAdvancementForTarget(roundId) != null) {
      showAdminModal(
        context,
        title: 'Adjust advanced contestants?',
        body: 'Explain the withdrawal or replacement. Official source ranking remains unchanged.',
        confirmLabel: 'Save Adjustment',
        requireReason: true,
        onConfirm: (reason) async {
          final error = await admin.adjustAdvancementAction(roundId, ids, reason);
          if (error == null && mounted) {
            setState(_selected.clear);
            notify(message);
          }
          return error;
        },
      );
    } else {
      admin.setRoundContestantsAction(roundId, ids).then((error) {
        if (!mounted) return;
        if (error == null) setState(_selected.clear);
        notify(error ?? message);
      });
    }
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.contestant, required this.assigned, required this.selected, required this.onSelect});
  final ContestantMaster contestant;
  final bool assigned, selected;
  final ValueChanged<bool>? onSelect;

  @override
  Widget build(BuildContext context) {
    final tiny = AdminLayout.tiny(context);
    final photoSize = tiny ? 92.0 : 112.0;
    final chip = AssignChip(assigned: assigned);
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        AdminCheckbox(value: selected, onChanged: onSelect),
        const SizedBox(width: 10),
        Container(
          width: photoSize,
          height: photoSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: AdminPhoto(photo: contestant.photo, name: contestant.name, fit: BoxFit.contain),
        ),
        const SizedBox(width: 17),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${contestant.numberLabel} · ${contestant.name}', style: ts(15, weight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 6),
            Text(contestant.profesi, style: ts(13, color: AppColors.textSecondary, height: 1.35)),
            if (tiny) ...[const SizedBox(height: 10), chip],
          ]),
        ),
        if (!tiny) ...[const SizedBox(width: 14), chip],
      ]),
    );
  }
}

/// `.admin-toggle-state` (Assigned / Unassigned).
class AssignChip extends StatelessWidget {
  const AssignChip({super.key, required this.assigned});
  final bool assigned;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: assigned ? AdminColors.successTint : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: assigned ? AdminColors.successBorder : AppColors.border),
        ),
        child: Text(assigned ? 'Assigned' : 'Unassigned',
            style: ts(12, weight: FontWeight.w700, color: assigned ? AppColors.success : AppColors.textSecondary)),
      );
}

/// Draft vs locked note shared by the configuration tabs.
class ConfigLockNote extends StatelessWidget {
  const ConfigLockNote({super.key, required this.locked});
  final bool locked;

  @override
  Widget build(BuildContext context) => AdminLockNote(
        locked
            ? 'Round configuration is locked while judging is open.'
            : 'Draft configuration can be edited before opening the round.',
        locked: locked,
      );
}

/// `.admin-readiness-summary` (4 facts; 2 columns on compact).
class ReadinessSummary extends StatelessWidget {
  const ReadinessSummary({super.key, required this.store, required this.roundId});
  final AdminStore store;
  final int roundId;

  @override
  Widget build(BuildContext context) {
    final r = store.getRoundReadiness(roundId);
    final cells = [
      ('${r.judgesAssigned}', 'Judges assigned'),
      ('${r.requiredJudges}', 'Required judges'),
      ('${r.requiredSubmitted} / ${r.requiredJudges}', 'Required submissions'),
      ('${pct(r.effectiveScoredWeight)}%', 'Effective scored weight'),
    ];
    final columns = AdminLayout.compact(context) ? 2 : 4;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: AdminGrid(
        columns: columns,
        gap: 1,
        children: [
          for (final (value, label) in cells)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: ts(20, weight: FontWeight.w700, tabular: true)),
                const SizedBox(height: 5),
                Text(label, style: ts(12, color: AppColors.textSecondary)),
              ]),
            ),
        ],
      ),
    );
  }
}
