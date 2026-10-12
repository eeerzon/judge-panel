// Admin routes — one per prototype page (judge-prototype/admin/*.html).
// Global destinations and Round Workspace tabs are separate state: every
// round-level route keeps the global "Rounds" item active.

import 'package:flutter/material.dart';

import 'admin_scope.dart';
import 'screens/advancement_screen.dart';
import 'screens/audit_screen.dart';
import 'screens/criteria_screen.dart';
import 'screens/events_screen.dart';
import 'screens/global_results_screen.dart';
import 'screens/live_screen.dart';
import 'screens/masters_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/result_detail_screen.dart';
import 'screens/round_contestants_screen.dart';
import 'screens/round_judges_screen.dart';
import 'screens/round_overview_screen.dart';
import 'screens/round_results_screen.dart';
import 'screens/rounds_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/submission_detail_screen.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_ui.dart';

class AdminRoutes {
  AdminRoutes._();
  // global — index.html, rounds.html, contestants.html, judges.html, live.html, results.html, settings.html, audit.html
  /// Event picker (API: `GET /judge/admin/dashboard`) — not in the HTML prototype.
  static const events = '/admin/events';
  static const overview = '/admin';
  static const rounds = '/admin/rounds';
  static const contestants = '/admin/contestants';
  static const judges = '/admin/judges';
  static const live = '/admin/live';
  static const results = '/admin/results';
  static const settings = '/admin/settings';
  static const audit = '/admin/audit';
  // round workspace — round.html, monitoring.html, submission-detail.html, round-contestants.html,
  // round-judges.html, criteria.html, round-results.html, result-detail.html, advancement.html
  static const roundOverview = '/admin/round';
  static const monitoring = '/admin/round/monitoring';
  static const submission = '/admin/round/submission';
  static const roundContestants = '/admin/round/contestants';
  static const roundJudges = '/admin/round/judges';
  static const criteria = '/admin/round/criteria';
  static const roundResults = '/admin/round/results';
  static const resultDetail = '/admin/round/result-detail';
  static const advancement = '/admin/round/advancement';

  static bool isAdmin(String? name) => name != null && name.startsWith('/admin');
}

class AdminRoundArgs {
  const AdminRoundArgs(this.roundId, {this.judgeId, this.contestantId});
  final String roundId;
  final String? judgeId;

  /// The app's local contestant id (not a server id).
  final int? contestantId;
}

class AdminNav {
  AdminNav._();

  static void go(BuildContext context, String route, [Object? args]) =>
      Navigator.of(context).pushReplacementNamed(route, arguments: args);

  static void round(BuildContext context, String route, String roundId, {String? judgeId, int? contestantId}) =>
      go(context, route, AdminRoundArgs(roundId, judgeId: judgeId, contestantId: contestantId));

  static Widget resolve(BuildContext context, RouteSettings settings) {
    // With the Admin API every page works on a chosen event.
    if (settings.name == AdminRoutes.events || AdminScope.read(context).needsEvent) {
      return const AdminEventsScreen();
    }
    switch (settings.name) {
      case AdminRoutes.overview:
        return const AdminOverviewScreen();
      case AdminRoutes.rounds:
        return const AdminRoundsScreen();
      case AdminRoutes.contestants:
        return const AdminContestantsScreen();
      case AdminRoutes.judges:
        return const AdminJudgesScreen();
      case AdminRoutes.live:
        return const AdminLiveScreen();
      case AdminRoutes.results:
        return const AdminResultsScreen();
      case AdminRoutes.settings:
        return const AdminSettingsScreen();
      case AdminRoutes.audit:
        return const AdminAuditScreen();
    }
    final args = settings.arguments is AdminRoundArgs ? settings.arguments as AdminRoundArgs : const AdminRoundArgs('');
    if (AdminScope.read(context).getRound(args.roundId) == null) return const _RoundNotFound();
    final id = args.roundId;
    return switch (settings.name) {
      AdminRoutes.monitoring => AdminMonitoringScreen(roundId: id),
      AdminRoutes.submission => AdminSubmissionScreen(roundId: id, judgeId: args.judgeId ?? ''),
      AdminRoutes.roundContestants => AdminRoundContestantsScreen(roundId: id),
      AdminRoutes.roundJudges => AdminRoundJudgesScreen(roundId: id),
      AdminRoutes.criteria => AdminCriteriaScreen(roundId: id),
      AdminRoutes.roundResults => AdminRoundResultsScreen(roundId: id),
      AdminRoutes.resultDetail => AdminResultDetailScreen(roundId: id, contestantId: args.contestantId ?? 0),
      AdminRoutes.advancement => AdminAdvancementScreen(roundId: id),
      _ => AdminRoundOverviewScreen(roundId: id),
    };
  }
}

class _RoundNotFound extends StatelessWidget {
  const _RoundNotFound();

  @override
  Widget build(BuildContext context) => AdminShell(activeNav: 'rounds', children: [
        AdminStateCard(
          title: 'Round not found',
          description: 'The round link is missing or does not point to a known round.',
          error: true,
          action: AdminBtn('View Rounds', onTap: () => AdminNav.go(context, AdminRoutes.rounds)),
        ),
      ]);
}
