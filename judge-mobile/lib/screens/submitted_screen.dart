// Post-submit confirmation — port of pages/submitted.html + submitted.js.
// Guarded in JudgeNav: only reachable once the round's sheet is submitted.

import 'package:flutter/material.dart';

import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/judge_chrome.dart';

class SubmittedScreen extends StatelessWidget {
  const SubmittedScreen({super.key, required this.roundId});
  final String roundId;

  @override
  Widget build(BuildContext context) {
    final store = JudgeScope.of(context);
    final round = store.getRound(roundId)!;
    final counts = store.countByStatus(roundId);
    final submittedAt = store.submittedAt(roundId);
    final portrait = isPortrait(context);

    return JudgeBackHandler(
      onBack: () => JudgeNav.goToMyRounds(context),
      child: Scaffold(
        body: SafeArea(
          child: JudgeChrome(
            roundId: roundId,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(portrait ? 24 : 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480 - 64),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.statusScoredFill,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.statusScoredFillBorder),
                          boxShadow: const [BoxShadow(color: AppColors.statusScoredGlow, blurRadius: 24)],
                        ),
                        child: Text('✓', style: ts(34, weight: FontWeight.w700, color: AppColors.statusScoredText)),
                      ),
                      const SizedBox(height: 12 + 8),
                      Text('Judging Submitted', textAlign: TextAlign.center, style: ts(28, weight: FontWeight.w700)),
                      const SizedBox(height: 8 + 2),
                      RoundLabel(round.name),
                      const SizedBox(height: 8 + 18),
                      Text('${counts.total} contestants scored', style: ts(17, weight: FontWeight.w600)),
                      if (submittedAt != null) ...[
                        const SizedBox(height: 8 + 4),
                        Text('Submitted at ${formatClock(submittedAt.toLocal())}',
                            style: ts(14, color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 8 + 14),
                      Text('Your scores are now locked.', style: ts(14, color: AppColors.textSecondary)),
                      const SizedBox(height: 8 + 28),
                      AppButton(
                        label: 'Back to My Rounds',
                        onTap: () => JudgeNav.goToMyRounds(context),
                        expand: true,
                        height: 56,
                        radius: 12,
                        fontSize: 16,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'View Submitted Scores',
                        onTap: () => JudgeNav.goToReview(context, roundId),
                        variant: AppButtonVariant.neutral,
                        expand: true,
                        height: 56,
                        radius: 12,
                        fontSize: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
