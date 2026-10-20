// admin/rounds.html — progression strip + round cards (admin.js `renderRounds`).

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/common.dart' show Pressable;
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../widgets/admin_rows.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_ui.dart';
import '../widgets/copy_public_link.dart';
import 'overview_screen.dart' show NoRoundsCard, showCreateRound;

class AdminRoundsScreen extends StatelessWidget {
  const AdminRoundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final rounds = admin.orderedRounds;
    final vertical = AdminLayout.tiny(context);

    Widget step(int i) {
      final r = rounds[i];
      final adv = admin.getAdvancement(r.id);
      return Pressable(
        onTap: () => AdminNav.round(context, AdminRoutes.roundOverview, r.id),
        pressedScale: 0.99,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.order.toString().padLeft(2, '0')} · ${r.name}', style: ts(14, weight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(
              '${r.status[0].toUpperCase()}${r.status.substring(1)}${adv != null ? ' · ${adv.selectedContestantIds.length} advanced' : ''}',
              style: ts(12, color: AppColors.textSecondary),
            ),
          ]),
        ),
      );
    }

    final arrow = Text(vertical ? '↓' : '→', style: ts(15, color: AppColors.accent));

    return AdminShell(activeNav: 'rounds', children: [
      AdminPageHeader(
        eyebrow: 'Event configuration',
        title: 'Rounds',
        description: 'Operational status and configuration readiness for every judging round.',
        actions: [
          if (CopyPublicLinkButton.available(admin)) const CopyPublicLinkButton(),
          AdminBtn('+ Create Round', variant: AdminBtnVariant.primary, onTap: () => showCreateRound(context)),
        ],
      ),
      if (rounds.isEmpty) const NoRoundsCard(),
      // .admin-progression-strip
      if (rounds.isNotEmpty) AdminPanel(
        padding: const EdgeInsets.all(14),
        child: vertical
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < rounds.length; i++) ...[
                  if (i > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Center(child: arrow)),
                  step(i),
                ],
              ])
            : IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < rounds.length; i++) ...[
                    if (i > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Center(child: arrow)),
                    Expanded(child: step(i)),
                  ],
                ]),
              ),
      ),
      const SizedBox(height: 20),
      AdminGrid(
        columns: AdminLayout.gridColumns(context, wide: 3),
        children: [for (final r in admin.rounds) AdminRoundCard(store: admin, round: r)],
      ),
    ]);
  }
}
