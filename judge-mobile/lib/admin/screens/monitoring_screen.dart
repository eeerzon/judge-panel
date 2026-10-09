// admin/monitoring.html — status-only judge monitoring with governance
// drawer (admin-governance.js `renderMonitoring` / `showDrawer`). No scores.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import '../widgets/admin_rows.dart';
import '../widgets/admin_ui.dart';
import '../widgets/round_workspace.dart';

class AdminMonitoringScreen extends StatefulWidget {
  const AdminMonitoringScreen({super.key, required this.roundId});
  final int roundId;

  @override
  State<AdminMonitoringScreen> createState() => _AdminMonitoringScreenState();
}

class _AdminMonitoringScreenState extends State<AdminMonitoringScreen> {
  String _filter = 'all';
  String _term = '';

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final roundId = widget.roundId;
    final round = admin.getRound(roundId)!;
    final ready = admin.getRoundReadiness(roundId);
    final all = admin.getMonitoringJudges(roundId);
    final rows = all.where((j) {
      final matches = _filter == 'all' ||
          (_filter == 'attention' && needsAttention(j)) ||
          (_filter == 'submitted' && ['submitted', 'resubmitted'].contains(j.submissionStatus)) ||
          (_filter == 'excused' && j.submissionStatus == 'excused');
      return matches && '${j.name} ${j.number}'.toLowerCase().contains(_term.toLowerCase());
    }).toList();
    final narrow = AdminLayout.narrow(context);

    return RoundWorkspace(
      roundId: roundId,
      activeTab: RoundTab.monitoring,
      pageTitle: 'Monitoring',
      pageDescription: 'Submission and connection status for this round.',
      children: [
        AdminStatGrid([
          AdminStatCard(value: '${ready.judgesAssigned}', label: 'Assigned judges'),
          AdminStatCard(value: '${ready.requiredSubmitted} / ${ready.requiredJudges}', label: 'Required submitted'),
          AdminStatCard(value: '${ready.optionalJudges}', label: 'Optional judges'),
          AdminStatCard(value: '${all.where(needsAttention).length}', label: 'Needs attention'),
        ]),
        if (round.status == 'closed' || round.status == 'finalized')
          AdminLockNote('Round ${round.status} · monitoring is read-only.'),
        _FilterBar(
          filters: const [('all', 'All'), ('attention', 'Needs Attention'), ('submitted', 'Submitted'), ('excused', 'Excused')],
          active: _filter,
          onFilter: (f) => setState(() => _filter = f),
          onSearch: (t) => setState(() => _term = t),
          hint: 'Search judge number or name',
        ),
        AdminList(
          header: narrow
              ? null
              : const AdminListHead(columns: [
                  ('Judge', 15), ('Progress', 8), ('Submission', 8), ('Connection', 7), ('Last sync', 5), ('Action', 0),
                ]),
          children: rows.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('No judges found', style: ts(17, weight: FontWeight.w700)),
                      const SizedBox(height: 7),
                      Text('Try another filter or search.', style: ts(14, color: AppColors.textSecondary)),
                    ]),
                  ),
                ]
              : [
                  for (final j in rows)
                    AdminDataRow(
                      name: j.name,
                      subtext: '${j.number} · ${j.required ? 'Required' : 'Optional'}',
                      meta: '${j.completed} / ${j.total} contestants',
                      status: AdminStatus(j.submissionStatus),
                      extra: AdminConnection(j.connection),
                      trailing: j.lastSync,
                      actionWidth: 90,
                      action: AdminBtn('View', small: true, onTap: () => showJudgeDrawer(context, roundId, j.id)),
                    ),
                ],
        ),
      ],
    );
  }
}

/// Search + filter pills (`.admin-filter-bar`).
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filters,
    required this.active,
    required this.onFilter,
    required this.onSearch,
    required this.hint,
  });
  final List<(String, String)> filters;
  final String active;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final pills = [for (final f in filters) AdminFilterPill(f.$2, active: active == f.$1, onTap: () => onFilter(f.$1))];
    final search = AdminSearchField(hint: hint, onChanged: onSearch);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // Stacked on compact screens and wherever search + pills do not fit on
      // one line (e.g. phone landscape with the 208px sidebar).
      child: LayoutBuilder(
        builder: (context, constraints) => AdminLayout.compact(context) || constraints.maxWidth < 720
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                search,
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, children: pills),
              ])
            : Row(children: [
                Expanded(child: search),
                for (final p in pills) ...[const SizedBox(width: 10), p],
              ]),
      ),
    );
  }
}

/// Judge detail drawer with governance actions (Monitoring).
void showJudgeDrawer(BuildContext context, int roundId, int judgeId) {
  final admin = AdminScope.read(context);
  showAdminDrawer<void>(
    context,
    title: admin.getMonitoringJudges(roundId).firstWhere((j) => j.id == judgeId).name,
    body: (ctx, _) {
      final store = AdminScope.of(ctx);
      final round = store.getRound(roundId)!;
      final judge = store.getMonitoringJudges(roundId).where((j) => j.id == judgeId).firstOrNull;
      if (judge == null) return const SizedBox.shrink();
      final history = store.getReopens(roundId).where((r) => r.judgeId == judgeId).toList();
      final last = history.isEmpty ? null : history.last;
      final assignment = store.getRoundJudges(roundId).where((e) => e.$1.judgeId == judgeId).firstOrNull?.$1;
      final items = <Widget>[
        AdminDetailItem(label: 'Judge', value: '${judge.number} · ${judge.required ? 'Required' : 'Optional'}'),
        AdminDetailItem(label: 'Round', value: round.name),
        AdminDetailItem(label: 'Progress', value: '${judge.completed} / ${judge.total} contestants'),
        AdminDetailItem(
            label: 'Submission',
            valueWidget: Align(alignment: Alignment.centerLeft, child: AdminStatus(judge.submissionStatus))),
        AdminDetailItem(
          label: 'Connection',
          value: '${connectionLabel(judge.connection)} · ${judge.lastSync}',
          last: last == null && judge.assignmentStatus != 'excused',
        ),
        if (last != null)
          AdminDetailItem(
            label: 'Reopened by / at',
            value: '${last.reopenedBy} · ${adminTime(last.reopenedAt)}',
            note: last.reason,
            last: judge.assignmentStatus != 'excused',
          ),
        if (judge.assignmentStatus == 'excused')
          AdminDetailItem(label: 'Excuse reason', value: assignment?.excuseReason ?? '—', last: true),
      ];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...items,
        if (judge.assignmentStatus == 'assigned' && judge.completed > 0) ...[
          const SizedBox(height: 16),
          const AdminLockNote(
              'This judge already has scoring activity. Use Excused or Reopen governance instead of Remove Assignment.'),
        ],
      ]);
    },
    footer: (ctx, _) {
      final store = AdminScope.of(ctx);
      final round = store.getRound(roundId)!;
      final judge = store.getMonitoringJudges(roundId).where((j) => j.id == judgeId).firstOrNull;
      if (judge == null) return [AdminBtn('Close', onTap: () => Navigator.of(ctx).pop())];
      final open = round.status == 'open';
      return [
        AdminBtn('Close', onTap: () => Navigator.of(ctx).pop()),
        if (judge.submissionStatus != 'removed' &&
            (judge.completed > 0 || ['submitted', 'resubmitted', 'reopened'].contains(judge.submissionStatus)))
          AdminBtn(judge.submissionStatus == 'in-progress' ? 'View Progress' : 'View Submission', onTap: () {
            Navigator.of(ctx).pop();
            AdminNav.round(context, AdminRoutes.submission, roundId, judgeId: judgeId);
          }),
        if (open && ['submitted', 'resubmitted'].contains(judge.submissionStatus))
          AdminBtn('Reopen Submission', variant: AdminBtnVariant.danger, onTap: () => governanceAction(ctx, store, roundId, judge, 'reopen')),
        if (open && judge.assignmentStatus == 'assigned')
          AdminBtn('Mark Excused', onTap: () => governanceAction(ctx, store, roundId, judge, 'excuse')),
        if (open && judge.submissionStatus == 'not-started' && judge.assignmentStatus == 'assigned')
          AdminBtn('Remove Assignment', onTap: () => governanceAction(ctx, store, roundId, judge, 'remove')),
        if (open && judge.assignmentStatus == 'excused')
          AdminBtn('Restore Judge', onTap: () => governanceAction(ctx, store, roundId, judge, 'restore')),
      ];
    },
  );
}

/// Confirmation (+ required reason for reopen/excuse) → store command.
Future<void> governanceAction(BuildContext context, AdminStore store, int roundId, MonitoringJudge judge, String action) async {
  final titles = {
    'reopen': "Reopen ${judge.name}'s submission?",
    'excuse': 'Mark ${judge.number} as excused?',
    'remove': 'Remove ${judge.number} from this round?',
    'restore': 'Restore ${judge.number}?',
  };
  final copy = {
    'reopen': 'The judge will be able to edit scores again.',
    'excuse': 'This judge will no longer be required to submit for this round.',
    'remove': 'Only a judge without scoring activity can be removed.',
    'restore': 'This judge can access the round again with the previous Required/Optional setting.',
  };
  final labels = {
    'reopen': 'Reopen Submission',
    'excuse': 'Mark Excused',
    'remove': 'Remove Assignment',
    'restore': 'Restore Judge',
  };
  await showAdminModal(
    context,
    title: titles[action]!,
    body: copy[action]!,
    confirmLabel: labels[action]!,
    confirmVariant: AdminBtnVariant.danger,
    requireReason: action == 'reopen' || action == 'excuse',
    onConfirm: (reason) => action == 'reopen'
        ? store.reopenAction(roundId, judge.id, reason)
        : store.judgeGovernanceAction(roundId, judge.id, action, reason),
  );
}
