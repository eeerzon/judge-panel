// admin/audit.html — local audit preview (admin-governance.js `renderAudit`).
// Not production audit evidence: the backend must generate append-only events.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import '../widgets/admin_rows.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_ui.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _State();
}

class _State extends State<AdminAuditScreen> {
  String _filter = 'all';

  static const _groups = {
    'submission': ['submit', 'reopen', 'resubmit'],
    'round': [
      'open', 'close', 'results-calculated', 'finalize', 'visibility-on', 'visibility-off',
      'advancement-confirmed', 'advancement-reset', 'advancement-adjusted', 'configuration-copied',
    ],
    'judge': ['excuse', 'restore', 'remove'],
  };

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final events = admin.getAuditEvents().where((e) => _filter == 'all' || _groups[_filter]!.contains(e.type)).toList();

    return AdminShell(activeNav: 'audit', children: [
      const AdminPageHeader(
        eyebrow: 'System',
        title: 'Audit Log',
        description: 'Local prototype preview of submission and governance events.',
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (key, label) in const [('all', 'All'), ('submission', 'Submission'), ('round', 'Round'), ('judge', 'Judge')])
            AdminFilterPill(label, active: _filter == key, onTap: () => setState(() => _filter = key)),
        ]),
      ),
      events.isEmpty
          ? const AdminStateCard(
              title: 'No events in this filter', description: 'Governance actions and resubmissions will appear here.')
          : AdminList(children: [for (final e in events) _AuditRow(event: e, store: admin)]),
    ]);
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.event, required this.store});
  final AuditEvent event;
  final AdminStore store;

  @override
  Widget build(BuildContext context) {
    final judge = event.judgeId == null ? null : store.getJudge(event.judgeId!);
    final round = event.roundId == null ? null : store.getRound(event.roundId!);
    final roundName = round?.name ?? 'Round';
    const judgeLabels = {
      'submit': 'submitted',
      'reopen': 'reopened',
      'resubmit': 'resubmitted',
      'excuse': 'marked Excused',
      'restore': 'restored',
      'remove': 'removed',
    };
    final roundEvents = {
      'open': '$roundName opened',
      'close': '$roundName closed',
      'results-calculated': '$roundName official results calculated',
      'finalize': '${event.actor} finalized $roundName results',
      'visibility-on': 'Judge result visibility enabled · $roundName',
      'visibility-off': 'Judge result visibility disabled · $roundName',
      'advancement-confirmed': '${event.actor} confirmed advancement from $roundName',
      'advancement-reset': 'Advancement from $roundName reset',
      'advancement-adjusted': 'Advanced contestants adjusted · $roundName',
      'configuration-copied': 'Round configuration copied · $roundName',
    };
    final description = roundEvents[event.type] ??
        '${judge?.name ?? 'Judge'} ${judgeLabels[event.type] ?? event.type}${round != null ? ' · $roundName' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 58,
          child: Text(adminTime(event.at), style: ts(14, weight: FontWeight.w700, color: AppColors.accent, tabular: true)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(description, style: ts(14, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${event.actor}${event.reason.isNotEmpty ? ' · Reason: ${event.reason}' : ''}',
                style: ts(12, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}
