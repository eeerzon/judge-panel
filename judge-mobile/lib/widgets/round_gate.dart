// Loads a round (round + contestants + criteria + score sheet) before any
// round screen renders, and applies the Judge access guard from
// navigation.js: the round must be judgeable (Open, not submitted) or
// already submitted (read-only view).

import 'package:flutter/material.dart';

import '../navigation/judge_nav.dart';
import '../screens/round_unavailable_screen.dart';
import '../state/app_scope.dart';
import '../state/judge_store.dart';
import '../theme/tokens.dart';
import 'common.dart';

class RoundGate extends StatefulWidget {
  const RoundGate({super.key, required this.roundId, required this.builder});

  final String roundId;
  final Widget Function(BuildContext context, JudgeStore store) builder;

  @override
  State<RoundGate> createState() => _RoundGateState();
}

class _RoundGateState extends State<RoundGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) JudgeScope.read(context).ensureRound(widget.roundId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = JudgeScope.of(context);
    final roundId = widget.roundId;
    final data = store.data(roundId);

    if (data == null) {
      final error = store.errorFor(roundId);
      if (error == null) return const _LoadingScreen();
      if (error.isForbidden) return RoundUnavailableScreen(message: error.message);
      return _LoadErrorScreen(
        message: error.message,
        onRetry: () => store.ensureRound(roundId, force: true),
      );
    }

    if (!store.canJudgeRound(roundId) && !store.isSubmitted(roundId)) {
      return RoundUnavailableScreen(
        message: data.contestants.isEmpty
            ? 'No contestants have been assigned to this round yet.'
            : 'This round is not open for scoring.',
      );
    }
    return widget.builder(context, store);
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return JudgeBackHandler(
      onBack: () => JudgeNav.goToMyRounds(context),
      child: Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            Text('Loading round…', style: ts(15, color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return JudgeBackHandler(
      onBack: () => JudgeNav.goToMyRounds(context),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Couldn't load this round", style: ts(28, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(message, style: ts(16, color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 24),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    AppButton(label: 'Try Again', onTap: onRetry, fontWeight: FontWeight.w700),
                    AppButton(
                      label: 'Back to My Rounds',
                      onTap: () => JudgeNav.goToMyRounds(context),
                      variant: AppButtonVariant.outline,
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
