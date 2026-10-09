// Splash — the app's initial route (Routes.splash). White background with
// the KREEN logo and the app version, continuing the native launch screen
// (same white + logo) so there is no jump when Flutter takes over.
//
// While visible it decides where to go:
//   no valid saved session → Login
//   saved session          → GET /judge/rounds, which also validates the
//                            token (401 ends the session → Login) and
//                            preloads My Rounds → Mode Selector (as the
//                            prototype's index.html → mode.html).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';

class SplashLogoPage extends StatefulWidget {
  const SplashLogoPage({super.key});

  /// Minimum time on screen, so the logo reads as intentional.
  static const minDuration = Duration(seconds: 2);

  /// Never hold the judge here for a slow network.
  static const maxWait = Duration(seconds: 6);

  @override
  State<SplashLogoPage> createState() => _SplashLogoPageState();
}

class _SplashLogoPageState extends State<SplashLogoPage> {
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final minimum = Future<void>.delayed(SplashLogoPage.minDuration);
      unawaited(_loadVersion());
      await _validateSession();
      await minimum;
      if (!mounted) return;
      _navigate();
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => appVersion = 'v${info.version}');
    } catch (_) {
      // Version is decorative; never block start-up on it.
    }
  }

  /// A saved token may have expired or been revoked server-side; loading the
  /// rounds checks it (a 401 logs out via the API client hook).
  Future<void> _validateSession() async {
    final session = SessionScope.read(context);
    // Only judges: owner/admin tokens are rejected by /judge/rounds for now
    // (401 would log them out); the Admin API checks their token instead.
    if (!session.hasJudgeSession || session.canAdmin) return;
    final store = JudgeScope.read(context);
    // The load keeps running after a timeout; My Rounds picks it up.
    await store.loadRounds().timeout(SplashLogoPage.maxWait, onTimeout: () {});
  }

  void _navigate() {
    if (SessionScope.read(context).hasJudgeSession) {
      JudgeNav.goToModeSelector(context);
    } else {
      JudgeNav.goToLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // White screen → dark status/navigation bar icons (the rest of the app is dark).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Image.asset(
                'assets/images/KreenOriginal.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                semanticLabel: 'KREEN',
              ),
            ),
            Positioned(
              bottom: 20,
              child: SafeArea(
                top: false,
                child: Text(
                  appVersion,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
