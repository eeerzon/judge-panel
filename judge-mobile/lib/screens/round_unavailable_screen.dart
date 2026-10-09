// Safe state for an unknown / unassigned / not-open round
// (navigation.js `showUnavailable()`).

import 'package:flutter/material.dart';

import '../navigation/judge_nav.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class RoundUnavailableScreen extends StatelessWidget {
  const RoundUnavailableScreen({super.key, this.message = 'This round is not assigned to you.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return JudgeBackHandler(
      onBack: () => JudgeNav.goToMyRounds(context),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.sizeOf(context).height * 0.18, 20, 40),
            child: MaxWidth(
              maxWidth: 560,
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('JUDGE MODE',
                        style: ts(12, weight: FontWeight.w700, color: AppColors.accentBright, letterSpacingEm: 0.16)),
                    const SizedBox(height: 10),
                    Text('Round unavailable', style: ts(36, weight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(message, style: ts(16, color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Back to My Rounds',
                      onTap: () => JudgeNav.goToMyRounds(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
