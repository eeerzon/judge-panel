// Idle / lock screen — port of pages/standby.html + standby.js.
// The whole screen is one tap target; wake always goes to Contestants
// (Gallery renders its own submitted/read-only state).

import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/judge_chrome.dart';

/// Fallback emblem on Standby when the event has no (loadable) banner.
const kEventLogoAsset = 'assets/images/kqp-logo.png';

class StandbyScreen extends StatefulWidget {
  const StandbyScreen({super.key, required this.roundId});
  final int roundId;

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _wake() => JudgeNav.goToContestants(context, widget.roundId);

  @override
  Widget build(BuildContext context) {
    final store = JudgeScope.of(context);
    final round = store.getRound(widget.roundId)!;
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height > size.width;
    final small = size.width <= 480;
    final logoWidth = portrait
        ? (small ? size.height * 0.26 : size.height * 0.30).clamp(0.0, small ? 160.0 : 200.0)
        : (size.height * 0.46).clamp(0.0, size.width >= 1024 ? 300.0 : 260.0);

    return JudgeBackHandler(
      onBack: () => JudgeNav.goToMyRounds(context),
      child: Scaffold(
        body: JudgeChrome(
          roundId: widget.roundId,
          child: Semantics(
            button: true,
            label: 'Tap anywhere to start judging',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _wake,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppColors.bgBase),
                  // .standby-glow — soft gold radial behind the logo
                  Center(
                    child: OverflowBox(
                      maxWidth: 1100,
                      maxHeight: 1100,
                      child: Container(
                        width: 1100,
                        height: 1100,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [AppColors.accentSoft, AppColors.accentBright.withValues(alpha: 0.05), Colors.transparent],
                            stops: [0, 0.35, 0.65],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // .standby-vignette
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.55)],
                        stops: [0.4, 1],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Stack(
                      children: [
                        Center(
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: _StandbyContent(
                              logoWidth: logoWidth,
                              year: store.eventYear(widget.roundId),
                              eventName: store.eventName(widget.roundId),
                              bannerUrl: round.eventBanner ??
                                  store.rounds?.where((r) => r.id == widget.roundId).firstOrNull?.eventBanner,
                              roundName: round.name,
                              submitted: store.isSubmitted(widget.roundId),
                              compact: small,
                              portrait: portrait,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 28,
                          right: 36,
                          child: Row(
                            children: [
                              BackLink('My Rounds', onTap: () => JudgeNav.goToMyRounds(context)),
                              const SizedBox(width: 28),
                              Text(formatClock(_now),
                                  style: ts(16, color: AppColors.textSecondary, letterSpacingEm: 0.03, tabular: true)),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 36,
                          right: 36,
                          bottom: portrait ? 24 : 28,
                          child: _Footer(portrait: portrait, connection: ConnectionStatusView(state: store.connectionState)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandbyContent extends StatelessWidget {
  const _StandbyContent({
    required this.logoWidth,
    required this.year,
    required this.eventName,
    this.bannerUrl,
    required this.roundName,
    required this.submitted,
    required this.compact,
    required this.portrait,
  });

  final double logoWidth;
  final int year;
  final String eventName;
  final String? bannerUrl;
  final String roundName;
  final bool submitted;
  final bool compact;
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 14.0 : 20.0;
    // Logo PNG has a solid background: a radial mask hides the square seam.
    final logo = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const RadialGradient(
        radius: 0.68,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0, 0.62, 1],
      ).createShader(rect),
      child: Image.asset(
        kEventLogoAsset,
        width: logoWidth,
        semanticLabel: eventName,
        errorBuilder: (_, _, _) => SizedBox(width: logoWidth, height: logoWidth),
      ),
    );
    final url = bannerUrl;
    // `vote.banner` comes in any shape (3000×2002, 1080×1350…): shown whole
    // inside a fixed box, decoded at display size (the files are ~1.5 MB).
    final maxWidth = logoWidth * 1.5;
    final banner = url == null
        ? logo
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: logoWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                // Web: /img_up/ sends no CORS header → an <img> element shows it anyway.
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                fit: BoxFit.contain,
                semanticLabel: eventName,
                cacheWidth: (maxWidth * MediaQuery.devicePixelRatioOf(context)).round(),
                frameBuilder: (_, child, frame, sync) => sync || frame != null
                    ? child
                    : SizedBox(width: logoWidth, height: logoWidth), // keeps the layout still while loading
                errorBuilder: (_, _, _) => logo,
              ),
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 4), child: banner),
        SizedBox(height: gap),
        Text('$year',
            style: ts(compact ? 13 : (portrait ? 15 : 16),
                weight: FontWeight.w500, color: AppColors.textSecondary, letterSpacingEm: compact ? 0.25 : 0.3)),
        SizedBox(height: gap),
        Container(
          width: 56,
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, AppColors.accentDeep, Colors.transparent]),
          ),
        ),
        SizedBox(height: gap),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: RoundLabel(roundName, size: 14, spacingEm: 0.28),
        ),
        if (submitted) ...[
          SizedBox(height: gap - 8),
          Text('Judging Submitted', style: ts(13, weight: FontWeight.w600, color: AppColors.statusScoredIcon)),
        ],
        SizedBox(height: gap + (portrait ? 28 : 36)),
        _PulseText('Tap anywhere to start', size: portrait ? 20 : 22),
      ],
    );
  }
}

/// `.tap-instruction` — calm opacity pulse (0.55 ↔ 1, 2.6s), not a splash.
class _PulseText extends StatefulWidget {
  const _PulseText(this.text, {required this.size});
  final String text;
  final double size;

  @override
  State<_PulseText> createState() => _PulseTextState();
}

class _PulseTextState extends State<_PulseText> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return FadeTransition(
      opacity: reduceMotion
          ? const AlwaysStoppedAnimation(1)
          : Tween(begin: 0.55, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Text(widget.text, style: ts(widget.size, weight: FontWeight.w500, color: AppColors.textSecondary)),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.portrait, required this.connection});
  final bool portrait;
  final Widget connection;

  @override
  Widget build(BuildContext context) {
    final identity = Text(SessionScope.of(context).judge?.identityLabel ?? '',
        style: ts(15, color: AppColors.textSecondary, letterSpacingEm: 0.02));
    if (portrait) {
      return Column(mainAxisSize: MainAxisSize.min, children: [identity, const SizedBox(height: 10), connection]);
    }
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [identity, connection]);
  }
}
