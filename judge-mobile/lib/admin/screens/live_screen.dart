// admin/live.html — event-level operations for the open round
// (admin-governance.js `renderLive`). Status only; scores stay private.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../widgets/admin_rows.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_ui.dart';

class AdminLiveScreen extends StatelessWidget {
  const AdminLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final active = admin.rounds.where((r) => r.status == 'open').firstOrNull;
    const header = AdminPageHeader(
      eyebrow: 'Event operations',
      title: 'Live',
      description: 'Round operations and submission monitoring.',
    );
    if (active == null) {
      return AdminShell(activeNav: 'live', children: [
        header,
        AdminStateCard(
          title: 'No round currently open',
          description: 'Review progression and open the next configured round when ready.',
          action: AdminBtn('View Rounds', onTap: () => AdminNav.go(context, AdminRoutes.rounds)),
        ),
      ]);
    }
    final ready = admin.getRoundReadiness(active.id);
    final compact = AdminLayout.compact(context);
    Widget stat(String value, String label) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: ts(22, weight: FontWeight.w700, tabular: true)),
          const SizedBox(height: 4),
          Text(label, style: ts(12, color: AppColors.textSecondary)),
        ]);
    final stats = [
      stat('${ready.judgesAssigned}', 'Assigned'),
      stat('${ready.requiredSubmitted} / ${ready.requiredJudges}', 'Required submitted'),
      stat('${ready.optionalJudges}', 'Optional'),
      stat('${ready.requiredJudges - ready.requiredSubmitted}', 'Needs submission'),
    ];
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AdminEyebrow('Current round'),
      const SizedBox(height: 7),
      Text(active.name, style: ts(22, weight: FontWeight.w700)),
      const SizedBox(height: 10),
      AdminStatus(active.status),
    ]);
    final button = AdminBtn('Open Monitoring',
        variant: AdminBtnVariant.primary,
        expand: AdminLayout.tiny(context),
        onTap: () => AdminNav.round(context, AdminRoutes.monitoring, active.id));

    return AdminShell(activeNav: 'live', children: [
      header,
      // .admin-live-active
      AdminPanel(
        padding: EdgeInsets.all(compact ? 18 : 24),
        child: compact
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                title,
                const SizedBox(height: 20),
                AdminGrid(columns: 2, gap: 18, children: stats),
                const SizedBox(height: 20),
                Align(alignment: Alignment.centerLeft, child: button),
              ])
            : Row(children: [
                Expanded(flex: 8, child: title),
                const SizedBox(width: 28),
                Expanded(flex: 20, child: AdminGrid(columns: 4, gap: 18, children: stats)),
                const SizedBox(width: 28),
                button,
              ]),
      ),
      const AdminSectionHeading(
        title: 'Judge submissions',
        subtitle: 'Event-level snapshot; score detail opens inside the selected Round Workspace.',
      ),
      AdminList(children: [
        for (final j in admin.getMonitoringJudges(active.id))
          AdminDataRow(
            name: j.name,
            subtext: '${j.number} · ${j.required ? 'Required' : 'Optional'}',
            meta: '${j.completed} / ${j.total} contestants',
            status: AdminStatus(j.submissionStatus),
            action: AdminBtn('View Submission',
                small: true, onTap: () => AdminNav.round(context, AdminRoutes.submission, active.id, judgeId: j.id)),
          ),
      ]),
    ]);
  }
}
