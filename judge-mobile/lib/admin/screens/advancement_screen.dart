// admin/advancement.html — explicit advancement decision from a finalized
// result (admin-advancement.js). Top N is preselected but never automatic.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../../widgets/common.dart' show BackLink;
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';

class AdminAdvancementScreen extends StatefulWidget {
  const AdminAdvancementScreen({super.key, required this.roundId});
  final int roundId;

  @override
  State<AdminAdvancementScreen> createState() => _State();
}

class _State extends State<AdminAdvancementScreen> {
  late final List<int> _defaults = AdminScope.read(context).getDefaultAdvancementIds(widget.roundId);
  late final Set<int> _selected = {..._defaults};
  final _reason = TextEditingController();
  String? _error;
  bool _preview = false;


  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final roundId = widget.roundId;
    final source = admin.getRound(roundId)!;
    final target = admin.getNextRound(roundId);
    final result = admin.calculateRoundResults(roundId);
    void back() => AdminNav.round(context, AdminRoutes.roundResults, roundId);

    if (target == null || !result.available || !result.finalized || admin.isAdvancementConfirmed(roundId)) {
      return RoundWorkspace(
        roundId: roundId,
        activeTab: RoundTab.results,
        pageTitle: 'Advancement Selection',
        pageDescription: 'Select the next round contestants.',
        onBack: back,
        children: [
          AdminStateCard(
            title: 'Advancement unavailable',
            description: 'Finalize this round before selecting contestants, or review its confirmed advancement.',
            action: AdminBtn('Back to Results', onTap: back),
          ),
        ],
      );
    }

    final count = source.advancementCount ?? 0;
    final cutoffTie = admin.hasAdvancementCutoffTie(roundId);
    final ids = [for (final i in result.items) if (_selected.contains(i.contestantId)) i.contestantId];
    final needsReason = cutoffTie || ids.any((id) => !_defaults.contains(id)) || ids.length != _defaults.length;
    final tiny = AdminLayout.tiny(context);

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.results,
      pageTitle: 'Advancement Selection',
      pageDescription: '${source.name} → ${target.name}',
      onBack: back,
      children: [
        Align(alignment: Alignment.centerLeft, child: BackLink('Official Results', onTap: back)),
        const SizedBox(height: 14),
        // .admin-advancement-intro
        AdminPanel(
          padding: const EdgeInsets.all(20),
          child: Flex(
            direction: tiny ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: tiny ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Flexible(
                fit: tiny ? FlexFit.loose : FlexFit.tight,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AdminEyebrow('${source.name} → ${target.name}'),
                  const SizedBox(height: 4),
                  Text('Choose $count advancing contestants', style: ts(17, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Top $count is preselected from the finalized result. Review before confirming; the official result will not change.',
                    style: ts(13, color: AppColors.textSecondary),
                  ),
                ]),
              ),
              SizedBox(width: tiny ? 0 : 20, height: tiny ? 14 : 0),
              Text('${ids.length} / $count selected',
                  style: ts(20, weight: FontWeight.w700, color: AppColors.accentBright, tabular: true)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (cutoffTie) ...[
          const AdminWarning(
            child: Text(
                'Tie at qualification cut. Contestants share the cutoff score. Make an explicit selection and explain the decision; official ranks stay tied.'),
          ),
          const SizedBox(height: 18),
        ],
        AdminPanel(
          child: Column(children: [
            for (final (i, item) in result.items.indexed)
              _AdvanceRow(
                item: item,
                first: i == 0,
                selected: _selected.contains(item.contestantId),
                onChanged: (v) => setState(() {
                  v ? _selected.add(item.contestantId) : _selected.remove(item.contestantId);
                  _preview = false;
                  _error = null;
                }),
              ),
          ]),
        ),
        if (needsReason)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: AdminPanel(
              padding: const EdgeInsets.all(18),
              child: AdminFormField(
                label: 'Reason for manual selection *',
                child: AdminTextField(
                  controller: _reason,
                  maxLines: 4,
                  hint: 'For example, a qualified contestant withdrew before the next round.',
                  onChanged: (_) => setState(() => _preview = false),
                ),
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: ts(12, weight: FontWeight.w600, color: AppColors.statusErrorColor)),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminBtn('Preview Advancement', variant: AdminBtnVariant.primary, onTap: () {
            final check = admin.validateAdvancement(roundId, ids, _reason.text);
            setState(() {
              _error = check.ok ? null : check.message;
              _preview = check.ok;
            });
          }),
        ),
        if (_preview) _previewPanel(context, result, ids, source, target),
      ],
    );
  }

  Widget _previewPanel(BuildContext context, RoundResult result, List<int> ids, AdminRound source, AdminRound target) {
    final admin = AdminScope.read(context);
    final check = admin.validateAdvancement(widget.roundId, ids, _reason.text);
    Widget names(Iterable<ResultItem> items) => Column(children: [
          for (final i in items)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Expanded(child: Text('${i.numberLabel} · ${i.name}', style: ts(13))),
                Text('Rank ${i.rank}', style: ts(13, weight: FontWeight.w700, color: AppColors.accent, tabular: true)),
              ]),
            ),
        ]);
    final advancing = result.items.where((i) => ids.contains(i.contestantId));
    final notAdvancing = result.items.where((i) => !ids.contains(i.contestantId));
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: AdminPanel(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AdminEyebrow('Preview · ${source.name} → ${target.name}'),
          const SizedBox(height: 4),
          Text('Advancing: ${advancing.length}', style: ts(17, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          names(advancing),
          const SizedBox(height: 18),
          Text('Not advancing: ${notAdvancing.length}', style: ts(17, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          names(notAdvancing),
          const SizedBox(height: 18),
          if (check.manual) AdminLockNote('Manual selection · Reason: ${_reason.text.trim()}'),
          Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
            AdminBtn('Cancel', onTap: () => setState(() => _preview = false)),
            AdminBtn('Confirm Advancement', variant: AdminBtnVariant.primary, onTap: () => _confirm(context, ids, target)),
          ]),
        ]),
      ),
    );
  }

  void _confirm(BuildContext context, List<int> ids, AdminRound target) {
    final admin = AdminScope.read(context);
    final source = admin.getRound(widget.roundId)!;
    showAdminModal(
      context,
      title: 'Advance ${ids.length} contestants to ${target.name}?',
      body: 'This creates their target-round assignment. Official ${source.name} results will not change.',
      confirmLabel: 'Confirm Advancement',
      onConfirm: (_) async {
        final error = await admin.confirmAdvancementAction(widget.roundId, ids, _reason.text);
        if (error != null) return error;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) AdminNav.round(context, AdminRoutes.roundOverview, target.id);
        });
        return null;
      },
    );
  }
}

class _AdvanceRow extends StatelessWidget {
  const _AdvanceRow({required this.item, required this.first, required this.selected, required this.onChanged});
  final ResultItem item;
  final bool first, selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tiny = AdminLayout.tiny(context);
    final score = Text(item.combinedScore.toStringAsFixed(2), style: ts(19, weight: FontWeight.w700, tabular: true));
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: EdgeInsets.symmetric(horizontal: tiny ? 12 : 18, vertical: 12),
        decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          AdminCheckbox(value: selected, onChanged: onChanged),
          SizedBox(width: tiny ? 4 : 8),
          SizedBox(
            width: tiny ? 34 : 58,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item.rank}', style: ts(22, weight: FontWeight.w700, color: AppColors.accentBright, tabular: true)),
              if (item.tied) Text('TIED', style: ts(10, weight: FontWeight.w700, color: AppColors.accentBright)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item.numberLabel} · ${item.name}', style: ts(14, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(item.profesi, style: ts(12, color: AppColors.textSecondary)),
              if (tiny) ...[const SizedBox(height: 4), score],
            ]),
          ),
          if (!tiny) SizedBox(width: 88, child: Align(alignment: Alignment.centerRight, child: score)),
        ]),
      ),
    );
  }
}
