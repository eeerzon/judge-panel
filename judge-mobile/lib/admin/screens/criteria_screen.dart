// admin/criteria.html — scoring hierarchy + effective weight (admin-round-config.js
// `criteriaContent`). One parent/group level; parents are never scored.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';
import 'round_contestants_screen.dart' show ConfigLockNote, ReadinessSummary;

class AdminCriteriaScreen extends StatelessWidget {
  const AdminCriteriaScreen({super.key, required this.roundId});
  final String roundId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final round = admin.getRound(roundId)!;
    final locked = round.status != 'draft';
    final criteria = admin.getCriteria(roundId)..sort((a, b) => a.sequence.compareTo(b.sequence));
    final total = AdminStore.effectiveScoredWeight(criteria);
    final message = total == 100
        ? '100% ✓'
        : total < 100
            ? '${pct(total)}% → ${pct(100 - total)}% remaining'
            : '${pct(total)}% → exceeds 100%';

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.criteria,
      pageTitle: 'Criteria',
      pageDescription: 'Configure the scoring hierarchy and effective scored weight.',
      children: [
        ConfigLockNote(locked: locked),
        ReadinessSummary(store: admin, roundId: roundId),
        // .admin-weight-callout
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: total == 100 ? const Color.fromRGBO(30, 158, 92, 0.14) : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(message,
                style: ts(12, weight: FontWeight.w800, color: total == 100 ? AppColors.success : AppColors.accent)),
          ),
        ),
        AdminPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Expanded(child: Text('Scoring hierarchy', style: ts(14, weight: FontWeight.w700))),
                AdminBtn('+ Add Criterion',
                    small: true, variant: AdminBtnVariant.primary, onTap: locked ? null : () => _openForm(context, null)),
              ]),
            ),
            ColoredBox(
              color: AppColors.border,
              child: Column(children: [
                for (final (i, c) in criteria.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 1),
                    child: _CriterionRow(
                      criterion: c,
                      parent: criteria.where((p) => p.id == c.parentId).firstOrNull,
                      onEdit: locked ? null : () => _openForm(context, c),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  void _openForm(BuildContext context, AdminCriterion? existing) {
    final admin = AdminScope.read(context);
    final settings = admin.eventSettings;
    final current = admin.getCriteria(roundId);
    final item = existing?.copy() ??
        AdminCriterion(
          id: '$roundId-custom-${DateTime.now().millisecondsSinceEpoch}',
          roundId: roundId,
          name: '',
          minScore: settings.minScore,
          maxScore: settings.maxScore,
          step: settings.step,
          required: settings.defaultCriterionRequired,
          sequence: current.length + 1,
        );
    final name = TextEditingController(text: item.name);
    final weight = TextEditingController(text: pct(item.weight));
    final min = TextEditingController(text: pct(item.minScore));
    final max = TextEditingController(text: pct(item.maxScore));
    final step = TextEditingController(text: pct(item.step));
    final sequence = TextEditingController(text: '${item.sequence}');
    String? parentId = item.parentId;
    var required = item.required, scored = item.isScored, isParent = item.isParent;
    var saving = false;
    String? error;
    final parents = current.where((c) => c.isParent && c.id != item.id).toList();

    showAdminDrawer<void>(
      context,
      title: existing == null ? 'Add Criterion' : 'Edit Criterion',
      body: (ctx, setState) {
        final twoCols = !AdminLayout.tiny(ctx);
        Widget pair(Widget a, Widget b) => twoCols
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)])
            : Column(children: [a, const SizedBox(height: 16), b]);
        Widget toggle(String label, bool value, ValueChanged<bool>? onChanged) => Container(
              constraints: const BoxConstraints(minHeight: 68),
              child: Row(children: [
                Expanded(
                    child: Text(label,
                        style: ts(14,
                            weight: FontWeight.w700,
                            color: onChanged == null ? AppColors.textSecondary : AppColors.textPrimary))),
                AdminToggle(on: value, onChanged: onChanged, semanticLabel: label),
              ]),
            );
        // A parent group is only a heading: never scored, 0% weight, no scale.
        final scoring = !isParent;
        const num = TextInputType.numberWithOptions(decimal: true);
        const whole = TextInputType.number;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          pair(
            AdminFormField(label: 'Name', child: AdminTextField(controller: name)),
            AdminFormField(
              label: 'Parent',
              // A parent group cannot sit under another parent.
              child: AdminSelect<String?>(
                value: isParent ? null : parentId,
                items: [(null, 'None'), for (final p in parents) (p.id, p.name)],
                enabled: !isParent,
                onChanged: (v) => setState(() => parentId = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          pair(
            AdminFormField(
                label: 'Weight %',
                child: AdminTextField(
                    controller: weight, keyboardType: num, inputFormatters: _decimal, isEnabled: scoring)),
            AdminFormField(
                label: 'Min score',
                child: AdminTextField(controller: min, keyboardType: whole, inputFormatters: _whole, isEnabled: scoring)),
          ),
          const SizedBox(height: 16),
          pair(
            AdminFormField(
                label: 'Max score',
                child: AdminTextField(controller: max, keyboardType: whole, inputFormatters: _whole, isEnabled: scoring)),
            AdminFormField(
                label: 'Step',
                child: AdminTextField(controller: step, keyboardType: num, inputFormatters: _decimal, isEnabled: scoring)),
          ),
          const SizedBox(height: 8),
          toggle('Required', required, scoring ? (v) => setState(() => required = v) : null),
          toggle('Scored criterion', scored, scoring ? (v) => setState(() => scored = v) : null),
          toggle('Parent group', isParent, (v) => setState(() {
                isParent = v;
                if (v) {
                  parentId = null;
                  scored = false;
                  weight.text = '0';
                } else {
                  scored = true;
                }
              })),
          const SizedBox(height: 8),
          AdminFormField(
              label: 'Sequence',
              child: AdminTextField(controller: sequence, keyboardType: TextInputType.number, inputFormatters: _whole)),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(error!, style: ts(13, color: AppColors.statusErrorColor, height: 1.5)),
          ],
        ]);
      },
      footer: (ctx, setState) => [
        if (existing != null)
          AdminBtn('Delete', variant: AdminBtnVariant.danger, onTap: saving
              ? null
              : () async {
                  setState(() => saving = true);
                  final failure = await admin.deleteCriterionAction(roundId, existing.id);
                  if (!ctx.mounted) return;
                  if (failure == null) return Navigator.of(ctx).pop();
                  setState(() {
                    saving = false;
                    error = failure;
                  });
                }),
        AdminBtn('Cancel', onTap: () => Navigator.of(ctx).pop()),
        AdminBtn(saving ? 'Saving…' : 'Save changes', variant: AdminBtnVariant.primary, onTap: saving ? null : () async {
          double n(TextEditingController c, double f) => double.tryParse(c.text.trim()) ?? f;
          if (!isParent) {
            final problem = validateCriterionScale(weight: weight.text, min: min.text, max: max.text, step: step.text);
            if (problem != null) return setState(() => error = problem);
          }
          final list = admin.getCriteria(roundId);
          var target = list.where((c) => c.id == item.id).firstOrNull;
          if (target == null) {
            target = item;
            list.add(target);
          }
          final wasParent = target.isParent;
          target
            ..name = name.text.trim().isEmpty ? 'Untitled criterion' : name.text.trim()
            ..parentId = parentId
            ..weight = n(weight, 0)
            ..minScore = n(min, 0)
            ..maxScore = n(max, 0)
            ..step = n(step, 0.25)
            ..required = required
            ..isParent = isParent;
          if (target.isParent) target.parentId = null;
          if (wasParent && !target.isParent) {
            for (final child in list) {
              if (child.parentId == target.id) child.parentId = null;
            }
          }
          target.isScored = !target.isParent && scored;
          if (target.isParent) target.weight = 0;
          target.sequence = int.tryParse(sequence.text.trim()) ?? list.length;
          setState(() {
            saving = true;
            error = null;
          });
          final failure = await admin.saveCriteriaAction(roundId, list);
          if (!ctx.mounted) return;
          if (failure == null) return Navigator.of(ctx).pop();
          setState(() {
            saving = false;
            error = failure;
          });
        }),
      ],
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({required this.criterion, required this.parent, required this.onEdit});
  final AdminCriterion criterion;
  final AdminCriterion? parent;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = criterion;
    final details = [
      if (parent != null) '${parent!.name} · ',
      c.isScored ? '${pct(c.minScore)}–${pct(c.maxScore)} · Step ${pct(c.step)}' : 'Non-scored',
      if (c.required) ' · Required',
    ].join();
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      color: c.isParent ? AppColors.surfaceAlt : AppColors.surface,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (c.isParent || parent != null) ...[
                AdminIcon(c.isParent ? 'caret' : 'child', size: 14, color: AppColors.textPrimary),
                const SizedBox(width: 6),
              ],
              Flexible(child: Text(c.name, style: ts(14, weight: FontWeight.w700))),
            ]),
            const SizedBox(height: 4),
            Text(details, style: ts(12, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 56,
          child: Text(c.isScored ? '${pct(c.weight)}%' : '—', style: ts(13, color: AppColors.textSecondary, tabular: true)),
        ),
        if (!AdminLayout.tiny(context)) ...[
          const SizedBox(width: 16),
          AdminStatus(c.isScored ? 'scored' : 'non-scored'),
        ],
        const SizedBox(width: 16),
        AdminBtn('Edit', small: true, onTap: onEdit),
      ]),
    );
  }
}

/// Min/Max/Sequence: digits only (no sign, no decimals).
final _whole = [FilteringTextInputFormatter.digitsOnly];

/// Weight/Step: an unsigned number with up to 2 decimals ("," is read as ".").
final _decimal = [
  TextInputFormatter.withFunction((oldValue, newValue) {
    final text = newValue.text.replaceAll(',', '.');
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) return oldValue;
    return newValue.copyWith(text: text);
  }),
];

/// Save-time check of a scored criterion's numbers; null when valid.
String? validateCriterionScale({required String weight, required String min, required String max, required String step}) {
  final w = double.tryParse(weight.trim());
  final lo = int.tryParse(min.trim()), hi = int.tryParse(max.trim());
  final s = double.tryParse(step.trim());
  if (w == null || w < 0 || w > 100) return 'Weight must be a number from 0 to 100.';
  if (lo == null || hi == null || lo < 0) return 'Min and Max score must be whole numbers of 0 or more.';
  if (hi <= lo) return 'Max score must be greater than Min score.';
  if (s == null || s <= 0 || s > hi - lo) return 'Step must be greater than 0 and no larger than Max − Min (${hi - lo}).';
  return null;
}
