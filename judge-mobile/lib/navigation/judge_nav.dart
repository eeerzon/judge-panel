// Judge Mode navigation + page guards — port of assets/js/navigation.js.
//
// The prototype used full page loads with `?round=N&id=M&from=review`.
// Here every navigation *replaces* the current route (no stack growth, like
// a page load) and the Android back button is mapped per-screen to the same
// action as the on-screen Back button (see JudgeBackHandler).

import 'package:flutter/material.dart';
import 'package:kreen_judge_mobile/screens/splash_logo_screen.dart';

import '../admin/admin_nav.dart';
import '../admin/admin_scope.dart';
import '../public/public_results.dart';
import '../public/public_results_screen.dart';
import '../screens/contestants_screen.dart';
import '../screens/login_screen.dart';
import '../screens/mode_selector_screen.dart';
import '../screens/my_rounds_screen.dart';
import '../screens/results_screen.dart';
import '../screens/review_screen.dart';
import '../screens/scoring_screen.dart';
import '../screens/submitted_screen.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/judge_theme.dart';
import '../widgets/round_gate.dart';
import '../widgets/themed_background.dart';

/// Where the Scoring page was opened from — decides where Back/exit goes.
enum ScoringOrigin { gallery, review }

class Routes {
  Routes._();
  static const splash = '/splash';
  static const login = '/login';
  static const modeSelector = '/mode';
  static const admin = AdminRoutes.overview;
  static const myRounds = '/rounds';
  static const standby = '/standby';
  static const contestants = '/contestants';
  static const scoring = '/scoring';
  static const review = '/review';
  static const submitted = '/submitted';
  static const results = '/results';
}

class RoundArgs {
  const RoundArgs(this.roundId);
  final String roundId;
}

class ScoringArgs extends RoundArgs {
  const ScoringArgs(super.roundId, this.contestantId, this.origin);
  final String contestantId;
  final ScoringOrigin origin;
}

class JudgeNav {
  JudgeNav._();

  static void _go(BuildContext context, String route, [Object? args]) {
    Navigator.of(context).pushReplacementNamed(route, arguments: args);
  }

  static void goToLogin(BuildContext context) => _go(context, Routes.login);
  static void goToModeSelector(BuildContext context) => _go(context, Routes.modeSelector);

  static void goToAdmin(BuildContext context) => _go(context, Routes.admin);
  static void goToMyRounds(BuildContext context) => _go(context, Routes.myRounds);
  static void goToContestants(BuildContext context, String roundId) =>
      _go(context, Routes.contestants, RoundArgs(roundId));
  static void goToScoring(BuildContext context, String roundId, String contestantId, [ScoringOrigin origin = ScoringOrigin.gallery]) =>
      _go(context, Routes.scoring, ScoringArgs(roundId, contestantId, origin));
  static void goToReview(BuildContext context, String roundId) => _go(context, Routes.review, RoundArgs(roundId));
  static void goToSubmitted(BuildContext context, String roundId) => _go(context, Routes.submitted, RoundArgs(roundId));
  static void goToResults(BuildContext context, String roundId) => _go(context, Routes.results, RoundArgs(roundId));

  /// Builds a route and runs the same guards as navigation.js:
  /// - no valid Judge session → Login
  /// - round not loadable / not assigned (403) / not open and not submitted
  ///   → "Round unavailable" (see [RoundGate])
  /// - scoring with an id outside the round → Contestants
  /// - submitted page before submission → Review
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 160),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, _, _) {
        // Public results link (no login): the page sets its own event theme.
        final public = parsePublicResultsRoute(settings.name);
        if (public != null) return PublicResultsScreen(slug: public.slug, orderNo: public.orderNo);
        // One page at a time (every navigation replaces the route), so the
        // page's palette is set right before it builds.
        final light = context.getInheritedWidgetOfExactType<AppearanceScope>()?.notifier?.light ?? false;
        final theme = _themeFor(context, settings);
        AppColors.palette = theme?.paletteFor(light: light) ?? AppPalette.kreenFor(light: light);
        // Every page but Splash and Login has the theme picture behind it
        // (Login also when it shows for a route without a session).
        final noPicture = settings.name == Routes.splash ||
            settings.name == Routes.login ||
            !SessionScope.read(context).hasJudgeSession;
        final picture = noPicture ? null : theme?.backgroundUrl ?? _pictureFor(context, settings);
        final page = Theme(data: buildAppTheme(backgroundPicture: picture != null), child: _resolve(context, settings));
        return picture == null ? page : ThemedBackground(url: picture, child: page);
      },
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
    );
  }

  /// Only the requested initial route — the default would also stack a
  /// hidden "/" route underneath, so Back on My Rounds wouldn't leave the app.
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) =>
      [onGenerateRoute(RouteSettings(name: initialRoute))];

  /// Judge Mode pages use their round's event theme, Admin pages the open
  /// event's (chosen, else the event's own) — colours, buttons and
  /// background picture. Login, Mode Selector, the event list and Splash
  /// keep KREEN (null).
  static EventTheme? _themeFor(BuildContext context, RouteSettings settings) {
    final themes = context.getInheritedWidgetOfExactType<JudgeThemeScope>()?.notifier;
    if (themes == null) return null;
    if (AdminRoutes.isAdmin(settings.name)) {
      final admin = context.getInheritedWidgetOfExactType<AdminScope>()?.notifier;
      final server = admin?.serverSettings;
      if (admin?.event == null || server == null || settings.name == AdminRoutes.events) return null;
      final id = server.idTheme ?? server.voteIdTheme ?? EventTheme.defaultId;
      return themes.themes.where((t) => t.id == id).firstOrNull ??
          EventTheme.builtIn.where((t) => t.id == id).firstOrNull;
    }
    final judge = JudgeScope.read(context);
    final args = settings.arguments;
    if (settings.name == Routes.myRounds) return themes.themeForEvents([for (final r in judge.rounds ?? const []) r.eventId]);
    if (args is RoundArgs && !AdminRoutes.isAdmin(settings.name)) {
      return themes.themeForEvents([judge.getRound(args.roundId)?.eventId]);
    }
    return null;
  }

  /// Picture of pages without a Judge Mode theme: Admin pages use the open
  /// event's theme (chosen, else the event's own), the rest the Default one.
  static String _pictureFor(BuildContext context, RouteSettings settings) {
    final admin = context.getInheritedWidgetOfExactType<AdminScope>()?.notifier;
    final server = admin?.serverSettings;
    final themeId = AdminRoutes.isAdmin(settings.name) && admin?.event != null
        ? server?.idTheme ?? server?.voteIdTheme ?? EventTheme.defaultId
        : EventTheme.defaultId;
    return EventTheme.backgroundUrlFor(themeId);
  }

  static Widget _resolve(BuildContext context, RouteSettings settings) {
    if (settings.name == Routes.splash) return const SplashLogoPage();
    final session = SessionScope.read(context);
    if (settings.name == Routes.login || !session.hasJudgeSession) return const LoginScreen();
    // Mode Selector offers only the workspaces of the account's actor_type;
    // a workspace the account may not open falls back to the selector.
    if (settings.name == Routes.modeSelector) return const ModeSelectorScreen();
    if (AdminRoutes.isAdmin(settings.name)) {
      // Admin Mode (port of judge-prototype/admin/*.html).
      return session.canAdmin ? AdminNav.resolve(context, settings) : const ModeSelectorScreen();
    }
    if (!session.canJudge) return const ModeSelectorScreen();
    if (settings.name == Routes.myRounds) return const MyRoundsScreen();

    final args = settings.arguments;
    if (args is! RoundArgs) return const MyRoundsScreen();
    final roundId = args.roundId;

    // Results carry their own server-side visibility gate.
    if (settings.name == Routes.results) return ResultsScreen(roundId: roundId);

    return RoundGate(
      roundId: roundId,
      builder: (context, store) {
        switch (settings.name) {
          case Routes.standby: // Standby is hidden for now → the gallery
            return ContestantsScreen(roundId: roundId);
          case Routes.contestants:
            return ContestantsScreen(roundId: roundId);
          case Routes.scoring:
            final scoring = args as ScoringArgs;
            if (store.getContestant(roundId, scoring.contestantId) == null) {
              return ContestantsScreen(roundId: roundId);
            }
            return ScoringScreen(roundId: roundId, contestantId: scoring.contestantId, origin: scoring.origin);
          case Routes.review:
            return ReviewScreen(roundId: roundId);
          case Routes.submitted:
            if (!store.isSubmitted(roundId)) return ReviewScreen(roundId: roundId);
            return SubmittedScreen(roundId: roundId);
        }
        return const MyRoundsScreen();
      },
    );
  }
}

/// Maps the system back gesture/button to the screen's own Back action,
/// since every route replaces the previous one.
class JudgeBackHandler extends StatelessWidget {
  const JudgeBackHandler({super.key, required this.onBack, required this.child});

  /// null → let the system handle it (e.g. leave the app from My Rounds).
  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack?.call();
      },
      child: child,
    );
  }
}
