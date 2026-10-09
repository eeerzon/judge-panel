// admin/results.html — event-level result status per round; no cross-round
// ranking and no advancement controls (admin-results-ui.js `renderGlobal`).

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_ui.dart';

class AdminResultsScreen extends StatelessWidget {
  const AdminResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    return AdminShell(activeNav: 'results', children: [
      AdminPageHeader(
        eyebrow: admin.eventSettings.eventName,
        title: 'Results',
        description: 'Event-level result status by round. No cross-round ranking is calculated.',
      ),
      AdminGrid(
        columns: AdminLayout.gridColumns(context, wide: 3),
        children: [
          for (final round in admin.rounds)
            () {
              final status = admin.getRoundResultStatus(round.id);
              final result = status == 'unavailable' ? null : admin.calculateRoundResults(round.id);
              Widget meta(String v, String c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v, style: ts(15, weight: FontWeight.w700, tabular: true)),
                    const SizedBox(height: 2),
                    Text(c, style: ts(12, color: AppColors.textSecondary)),
                  ]);
              return Container(
                constraints: const BoxConstraints(minHeight: 246),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${round.order.toString().padLeft(2, '0')} · ROUND',
                            style: ts(12, weight: FontWeight.w700, color: AppColors.accent, letterSpacingEm: 0.12)),
                        const SizedBox(height: 9),
                        Text(round.name, style: ts(20, weight: FontWeight.w700)),
                      ]),
                    ),
                    AdminStatus(round.status),
                  ]),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: meta('${result?.contestantCount ?? admin.getRoundContestants(round.id).length}', 'Contestants')),
                    Expanded(child: meta(result == null ? '—' : '${result.eligibleJudgeCount}', 'Eligible Judges')),
                  ]),
                  const SizedBox(height: 24),
                  Text(
                    status == 'finalized'
                        ? 'Official Results Ready'
                        : status == 'provisional'
                            ? 'Provisional Admin Result'
                            : round.status == 'open'
                                ? 'Unavailable while judging is open'
                                : 'No results yet',
                    style: ts(13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Spacer(),
                  status != 'unavailable'
                      ? AdminBtn('View Results',
                          expand: true,
                          variant: AdminBtnVariant.primary,
                          onTap: () => AdminNav.round(context, AdminRoutes.roundResults, round.id))
                      : const AdminBtn('No results', small: true),
                ]),
              );
            }(),
        ],
      ),
    ]);
  }
}
