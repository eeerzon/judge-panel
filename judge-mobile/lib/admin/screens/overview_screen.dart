// admin/index.html — Judging Overview (admin.js `renderOverview`).

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../widgets/admin_rows.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_ui.dart';
import '../widgets/copy_public_link.dart';

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final active = admin.activeRound;

    final header = AdminPageHeader(
      eyebrow: 'Event overview',
      title: 'Judging Overview',
      description: 'A calm operational view of your rounds, assignments, and judging progress.',
      actions: [
        if (CopyPublicLinkButton.available(admin)) const CopyPublicLinkButton(),
        AdminBtn('+ Create Round', variant: AdminBtnVariant.primary, onTap: () => showCreateRound(context))
      ],
    );
    if (active == null) {
      return AdminShell(activeNav: 'overview', children: [header, const NoRoundsCard()]);
    }
    final ready = admin.getRoundReadiness(active.id);
    final progress = ready.submissionSummary;
    final previous = admin.getPreviousRound(active.id);
    final next = admin.getNextRound(active.id);
    final monitoring = admin.getMonitoringJudges(active.id);
    final preview = monitoring.length > 2 ? monitoring.sublist(2, monitoring.length < 5 ? monitoring.length : 5) : monitoring;

    return AdminShell(activeNav: 'overview', children: [
      header,
      AdminStatGrid([
        AdminStatCard(
          value: active.name,
          label: 'Current stage · ${active.status}',
          note: '${previous != null ? 'Previous: ${previous.name} · ${previous.status}' : 'First round'}'
              '${next != null ? ' · Next: ${next.name} · ${next.status}' : ''}',
        ),
        AdminStatCard(value: '${ready.contestantsAssigned}', label: 'Contestants', note: active.name),
        AdminStatCard(value: '${ready.judgesAssigned}', label: 'Assigned Judges', note: active.name),
        AdminStatCard(
          value: '${progress.submitted} / ${progress.total}',
          label: 'Judges Submitted',
          noteWidget: AdminLink('Open ${active.name} Workspace',
              color: AppColors.success, onTap: () => AdminNav.round(context, AdminRoutes.roundOverview, active.id)),
        ),
      ]),
      AdminSectionHeading(
        title: 'Rounds',
        subtitle: 'Current judging configuration and progress.',
        trailing: [AdminBtn('View All Rounds', small: true, onTap: () => AdminNav.go(context, AdminRoutes.rounds))],
      ),
      AdminGrid(
        columns: AdminLayout.gridColumns(context, wide: 3),
        children: [for (final r in admin.rounds) AdminRoundCard(store: admin, round: r)],
      ),
      AdminSectionHeading(
        title: 'Live judging',
        subtitle: 'Status-only operational monitoring. Scores stay private.',
        trailing: [AdminBtn('Open Live', small: true, onTap: () => AdminNav.go(context, AdminRoutes.live))],
      ),
      AdminList(children: [
        for (final j in preview)
          AdminDataRow(
            name: j.name,
            subtext: '${j.number} · ${active.name}',
            meta: '${j.completed} / ${j.total} contestants',
            status: AdminStatus(j.submissionStatus),
            action: AdminBtn('View Live', small: true, onTap: () => AdminNav.go(context, AdminRoutes.live)),
          ),
      ]),
    ]);
  }
}

/// Empty state of an event without rounds (Overview + Rounds).
class NoRoundsCard extends StatelessWidget {
  const NoRoundsCard({super.key});

  @override
  Widget build(BuildContext context) => AdminStateCard(
        title: 'No rounds yet',
        description: 'Create the first judging round for this event to start configuring contestants, judges, and criteria.',
        action: AdminBtn('+ Create Round', variant: AdminBtnVariant.primary, onTap: () => showCreateRound(context)),
      );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: AppColors.surfaceRaised,
    content: Text(message, style: ts(14)),
  ));
}

/// "+ Create Round" — `POST /judge/admin/events/{idVote}/rounds`. Without the
/// Admin API (prototype seed) it has no behavior, like the HTML prototype.
void showCreateRound(BuildContext context) => showRoundForm(context);

/// Create (`POST events/{idVote}/rounds`) or edit (`PATCH rounds/{id}`) a
/// round; a draft round can also be deleted (`DELETE rounds/{id}`).
void showRoundForm(BuildContext context, {AdminRound? round}) {
  final admin = AdminScope.read(context);
  if (!admin.connected || admin.event == null) {
    _snack(context, 'Round creation is not available yet in this prototype.');
    return;
  }
  final name = TextEditingController(text: round?.name ?? '');
  final topN = TextEditingController(text: '${round?.advancementCount ?? 10}');
  var mode = round?.promoteMode == 'manual' ? 'manual' : 'auto_top_n';
  var favorite = round?.favoritPromoteEnabled ?? false;
  var saving = false;
  String? error;
  showAdminDrawer<void>(
    context,
    title: round == null ? 'Create Round' : 'Edit Round',
    body: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminFormField(
        label: 'Round name',
        child: AdminTextField(
            controller: name, hint: 'e.g. Top 10', autofocus: round == null, error: error != null && name.text.trim().isEmpty),
      ),
      const SizedBox(height: 16),
      AdminFormField(
        label: 'Advancement',
        child: AdminSelect<String>(
          value: mode,
          items: const [('auto_top_n', 'Top N from official result'), ('manual', 'Manual selection')],
          onChanged: (v) => setState(() => mode = v),
        ),
      ),
      const SizedBox(height: 16),
      AdminFormField(
        label: 'Contestants advancing (Top N)',
        child: AdminTextField(controller: topN, keyboardType: TextInputType.number),
      ),
      const SizedBox(height: 8),
      Container(
        constraints: const BoxConstraints(minHeight: 68),
        child: Row(children: [
          Expanded(child: Text('Favorite vote advances', style: ts(14, weight: FontWeight.w700))),
          AdminToggle(
            on: favorite,
            onChanged: (v) => setState(() => favorite = v),
            semanticLabel: 'Favorite vote advances',
          ),
        ]),
      ),
      if (error != null) ...[
        const SizedBox(height: 8),
        Text(error!, style: ts(13, color: AppColors.statusErrorColor)),
      ],
    ]),
    footer: (ctx, setState) => [
      if (round != null && round.status == 'draft')
        AdminBtn('Delete', variant: AdminBtnVariant.danger, onTap: saving ? null : () => _deleteRound(context, ctx, round)),
      AdminBtn('Cancel', onTap: () => Navigator.of(ctx).pop()),
      AdminBtn(saving ? 'Saving…' : (round == null ? 'Create Round' : 'Save changes'),
          variant: AdminBtnVariant.primary,
          onTap: saving
              ? null
              : () async {
                  final n = int.tryParse(topN.text.trim());
                  if (name.text.trim().isEmpty || n == null || n < 1) {
                    setState(() => error = name.text.trim().isEmpty
                        ? 'Round name is required.'
                        : 'Enter how many contestants advance (1 or more).');
                    return;
                  }
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  final failure = round == null
                      ? (await admin.createRound(
                          name: name.text,
                          promoteMode: mode,
                          promoteTopN: n,
                          favoritPromoteEnabled: favorite,
                        ))
                          .message
                      : await admin.updateRoundAction(round.id,
                          name: name.text, promoteMode: mode, promoteTopN: n, favoritPromoteEnabled: favorite);
                  if (!ctx.mounted) return;
                  if (failure == null) {
                    Navigator.of(ctx).pop();
                    if (context.mounted) _snack(context, round == null ? 'Round created.' : 'Round updated.');
                  } else {
                    setState(() {
                      saving = false;
                      error = failure;
                    });
                  }
                }),
    ],
  );
}

Future<void> _deleteRound(BuildContext page, BuildContext drawer, AdminRound round) async {
  final admin = AdminScope.read(page);
  String? failure;
  final confirmed = await showAdminModal(
    drawer,
    title: 'Delete ${round.name}?',
    body: 'The draft round and its configuration are removed. This cannot be undone.',
    confirmLabel: 'Delete Round',
    confirmVariant: AdminBtnVariant.danger,
    onConfirm: (_) async => failure = await admin.deleteRoundAction(round.id),
  );
  if (!confirmed || failure != null || !page.mounted) return;
  if (drawer.mounted) Navigator.of(drawer).pop();
  // Leave the round's pages before the round disappears from the store.
  AdminNav.go(page, AdminRoutes.rounds);
  _snack(page, 'Round deleted.');
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await admin.refreshEvent();
}
