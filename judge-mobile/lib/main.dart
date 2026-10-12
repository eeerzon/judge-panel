import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin/admin_store.dart';
import 'api/admin_api.dart';
import 'api/api_client.dart';
import 'api/judge_api.dart';
import 'navigation/judge_nav.dart';
import 'state/app_scope.dart';
import 'state/judge_store.dart';
import 'state/session_store.dart';
import 'theme/appearance.dart';
import 'theme/judge_theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tablet landscape is the default/primary orientation (NFR). The native
  // configs (AndroidManifest `sensorLandscape`, iOS Info.plist) lock it too.
  // Layouts still adapt to portrait, so dropping this lock later is safe.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bgBase,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final client = ApiClient();
  final api = HttpJudgeApi(client);
  final session = await SessionStore.load(api);
  final judge = await JudgeStore.create(api);
  final admin = await AdminStore.load(api: HttpAdminApi(client));
  final themes = await JudgeThemeStore.load();
  final appearance = await AppearanceStore.load();
  client
    ..tokenProvider = (() => session.token)
    ..onUnauthorized = session.handleUnauthorized;
  runApp(KreenJudgeApp(judge: judge, session: session, admin: admin, themes: themes, appearance: appearance));
}

class KreenJudgeApp extends StatefulWidget {
  KreenJudgeApp({super.key, required this.judge, required this.session, AdminStore? admin, this.themes, this.appearance})
      : admin = admin ?? AdminStore.memory();

  final JudgeStore judge;
  final SessionStore session;

  /// Admin Mode state (events/rounds/contestants from the Admin API).
  final AdminStore admin;

  /// Judge Mode theme per event (Admin Settings).
  final JudgeThemeStore? themes;

  /// Night / light mode (night when omitted).
  final AppearanceStore? appearance;

  @override
  State<KreenJudgeApp> createState() => _KreenJudgeAppState();
}

class _KreenJudgeAppState extends State<KreenJudgeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _routes = _CurrentRoute();
  late final AppearanceStore _appearance = widget.appearance ?? AppearanceStore();
  late bool _signedIn;

  /// How long "Session expired" stays up before Login opens.
  static const expiredNoticeDuration = Duration(seconds: 3);
  bool _expiring = false;

  @override
  void initState() {
    super.initState();
    // Read now, not lazily: a lazy first read would happen only after the
    // session ended and miss the transition (Log Out / 401 did nothing).
    _signedIn = widget.session.hasJudgeSession;
    widget.judge.bindJudge(widget.session.judge?.id);
    _syncAdminActor();
    widget.session.addListener(_onSessionChanged);
    _appearance.addListener(_onAppearanceChanged);
    AppColors.palette = AppPalette.kreenFor(light: _appearance.light);
    _applySystemBars();
  }

  /// Colours are read when a page builds: re-open the current page in the
  /// new mode (every navigation replaces the page, so nothing stacks).
  void _onAppearanceChanged() {
    // Root theme (dialogs) follows at once; the page sets its own palette.
    AppColors.palette = AppPalette.kreenFor(light: _appearance.light);
    setState(() {});
    _applySystemBars();
    final current = _routes.current;
    if (current?.name == null) return;
    _navigatorKey.currentState?.pushReplacementNamed(current!.name!, arguments: current.arguments);
  }

  void _applySystemBars() => SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _appearance.light ? Brightness.dark : Brightness.light,
        statusBarBrightness: _appearance.light ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: AppPalette.kreenFor(light: _appearance.light).bgBase,
        systemNavigationBarIconBrightness: _appearance.light ? Brightness.dark : Brightness.light,
      ));

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _appearance.removeListener(_onAppearanceChanged);
    super.dispose();
  }

  /// Scopes local drafts to the judge, and returns to Login whenever the
  /// session ends (logout, expired or revoked token → 401).
  void _onSessionChanged() {
    final session = widget.session;
    if (!session.hasJudgeSession && _signedIn && session.expiredMessage != null) {
      // Token expired / revoked (401): tell the user first, then Login.
      _signedIn = false;
      _showExpiredThenLogin(session.expiredMessage!);
      return;
    }
    if (_expiring) return; // Login opens when the notice ends
    widget.judge.bindJudge(session.hasJudgeSession ? session.judge?.id : null);
    if (!session.hasJudgeSession) {
      if (_signedIn) widget.admin.clearSession();
      // Also when the session had already lapsed: Log Out must always land on Login.
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(Routes.login, (_) => false);
    }
    _signedIn = session.hasJudgeSession;
    _syncAdminActor();
  }

  /// Shows the "Session expired" modal over the current page for
  /// [expiredNoticeDuration] (or until "Sign In Now"), then clears the
  /// session data and opens Login. The data is cleared only then, so the page
  /// behind the modal never loses what it is showing.
  void _showExpiredThenLogin(String message) {
    if (_expiring) return;
    _expiring = true;
    var done = false;
    void goToLogin() {
      if (done) return;
      done = true;
      _expiring = false;
      widget.judge.bindJudge(null);
      widget.admin.clearSession();
      _syncAdminActor();
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(Routes.login, (_) => false);
    }

    final overlay = _navigatorKey.currentState?.overlay;
    if (overlay == null) return goToLogin();
    unawaited(showDialog<void>(
      context: overlay.context,
      barrierDismissible: false,
      barrierColor: const Color.fromRGBO(8, 4, 4, 0.72),
      builder: (_) => PopScope(canPop: false, child: _SessionExpiredDialog(message: message, onSignIn: goToLogin)),
    ));
    Timer(expiredNoticeDuration, goToLogin);
  }

  /// Governance/audit actor = the signed-in account.
  void _syncAdminActor() => widget.admin.actor = widget.session.judge?.name ?? 'Super Admin';

  @override
  Widget build(BuildContext context) {
    return AppScope(
      judge: widget.judge,
      session: widget.session,
      admin: widget.admin,
      themes: widget.themes,
      appearance: _appearance,
      child: MaterialApp(
        title: 'KREEN Judge',
        navigatorKey: _navigatorKey,
        navigatorObservers: [_routes],
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        // Splash first (SplashLogoPage): continues the native launch screen and
        // decides between Login and My Rounds.
        initialRoute: Routes.splash,
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: JudgeNav.onGenerateInitialRoutes,
        // Text scaling is capped so extreme accessibility scaling cannot
        // break the fixed-size scoring controls, while still allowing 1.3×.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
            child: child!,
          );
        },
      ),
    );
  }
}

/// "Session expired" notice (token expired or revoked) shown before Login.
class _SessionExpiredDialog extends StatelessWidget {
  const _SessionExpiredDialog({required this.message, required this.onSignIn});
  final String message;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.surfaceRaised,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderStrong),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Session expired', style: ts(20, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(message, style: ts(14, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 6),
              Text('Opening sign in…', style: ts(13, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              Row(children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBright),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSignIn,
                  child: Text('Sign In Now', style: ts(14, weight: FontWeight.w700, color: AppColors.accentBright)),
                ),
              ]),
            ]),
          ),
        ),
      );
}

/// Tracks the page on screen (to re-open it when the mode changes).
class _CurrentRoute extends NavigatorObserver {
  RouteSettings? current;

  void _set(Route<dynamic>? route) {
    if (route is PageRoute) current = route.settings;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
}
