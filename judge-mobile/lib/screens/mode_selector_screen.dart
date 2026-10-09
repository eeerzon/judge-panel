// Workspace / Mode Selector — 1:1 port of judge-prototype/mode.html
// (+ entry.css). Shown after login and on start-up with a saved session, with
// only the workspaces the login's `actor_type` allows: owner → Admin + Judge,
// admin → Admin, judge → Judge (one card uses the prototype's `.is-single`).

import 'package:flutter/material.dart';

import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../state/session_store.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'login_screen.dart' show KreenMark;

enum AppMode { admin, judge }

class ModeSelectorScreen extends StatelessWidget {
  const ModeSelectorScreen({super.key});

  /// Workspaces the signed-in account may open (session.js `modesFor`).
  static List<AppMode> availableModes(SessionStore session) => [
        if (session.canAdmin) AppMode.admin,
        if (session.canJudge) AppMode.judge,
      ];

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final name = session.judge?.name ?? '';

    return JudgeBackHandler(
      onBack: null, // leaving the workspace chooser leaves the app
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final vw = MediaQuery.sizeOf(context).width;
            final vh = MediaQuery.sizeOf(context).height;
            final tiny = width <= 440;
            // .mode-layout: width min(1060px,100%), padding 30px clamp(24px,5vw,68px) 70px
            final padX = tiny ? 16.0 : (vw * 0.05).clamp(24.0, 68.0);

            final cards = [
              for (final mode in availableModes(session))
                _ModeCard(
                  mode: mode,
                  compact: tiny,
                  onOpen: () => mode == AppMode.judge ? JudgeNav.goToMyRounds(context) : JudgeNav.goToAdmin(context),
                ),
            ];

            return SingleChildScrollView(
              child: MaxWidth(
                maxWidth: 1060,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padX, 30, padX, 70),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // .mode-header
                      Row(children: [
                        const KreenMark(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('KREEN JUDGING',
                              style: ts(tiny ? 11 : 12,
                                  weight: FontWeight.w800, color: AppColors.accentBright, letterSpacingEm: 0.17)),
                        ),
                        const SizedBox(width: 20),
                        _TextButton(label: 'Log Out', onTap: () => SessionScope.read(context).logout()),
                      ]),
                      // .mode-intro: margin clamp(54px, 10vh, 112px) 0 30px
                      SizedBox(height: width <= 760 ? 58 : (vh * 0.10).clamp(54.0, 112.0)),
                      Text('YOUR WORKSPACE',
                          style: ts(12, weight: FontWeight.w800, color: AppColors.accentBright, letterSpacingEm: 0.13)),
                      const SizedBox(height: 7),
                      Text('Good to see you,', style: ts(15, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Text(name,
                          style: ts((vw * 0.04).clamp(32.0, 48.0), weight: FontWeight.w700, letterSpacingEm: -0.035)),
                      const SizedBox(height: 22),
                      Text('Choose how you want to continue', style: ts(21, weight: FontWeight.w600)),
                      const SizedBox(height: 30),
                      // .mode-options: always side by side in a Row (the app is
                      // landscape-only, so no stacked ≤760px variant). A single
                      // mode keeps the prototype's 510px `.is-single` width.
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cards.length == 1 ? 510 : double.infinity),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                if (i > 0) SizedBox(width: tiny ? 12 : 18),
                                Expanded(child: cards[i]),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.compact, required this.onOpen});
  final AppMode mode;
  final bool compact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (label, heading, description, action) = switch (mode) {
      AppMode.admin => (
          'ADMIN MODE',
          'Manage judging operations',
          'Set up rounds, coordinate judges and contestants, monitor progress, and manage results.',
          'Open Admin',
        ),
      AppMode.judge => (
          'JUDGE MODE',
          'Score assigned rounds',
          'View your assigned rounds and continue contestant scoring.',
          'Open Judge Mode',
        ),
    };
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 270 : 290),
      padding: EdgeInsets.all(compact ? 22 : 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.18), blurRadius: 55, offset: Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .mode-icon
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.borderStrong),
              ),
              // Drawn, not text: ◫ / ✦ are not in Inter and not guaranteed
              // by the Android system fonts.
              child: CustomPaint(size: const Size(18, 18), painter: _ModeGlyphPainter(mode)),
            ),
          ),
          const SizedBox(height: 26),
          Text(label, style: ts(12, weight: FontWeight.w800, color: AppColors.accentBright, letterSpacingEm: 0.13)),
          const SizedBox(height: 7),
          Text(heading, style: ts(20, weight: FontWeight.w700)),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(description, style: ts(14, color: AppColors.textSecondary, height: 1.55)),
          ),
          const SizedBox(height: 24),
          const Spacer(),
          // .entry-btn (16px / 400 via `.entry-body button { font: inherit }`)
          AppButton(
            label: action,
            trailing: Text('→', style: ts(16)),
            onTap: onOpen,
            expand: true,
            height: 48,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }
}

/// `.entry-text-button` ("Log Out") — renders 16px/400 because of the same
/// `font: inherit` rule.
class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          widthFactor: 1,
          child: Text(label, style: ts(16, color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

/// The prototype's `◫` (Admin) and `✦` (Judge) glyphs, in accent-bright.
class _ModeGlyphPainter extends CustomPainter {
  _ModeGlyphPainter(this.mode);
  final AppMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (mode == AppMode.admin) {
      final stroke = Paint()
        ..color = AppColors.accentBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      final box = Rect.fromLTWH(w * 0.14, h * 0.1, w * 0.72, h * 0.8);
      canvas.drawRect(box, stroke);
      canvas.drawLine(Offset(box.center.dx, box.top), Offset(box.center.dx, box.bottom), stroke);
    } else {
      // Four-pointed star with concave sides.
      final c = Offset(w / 2, h / 2);
      final r = w * 0.5;
      final k = r * 0.16;
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, Paint()..color = AppColors.accentBright);
    }
  }

  @override
  bool shouldRepaint(_ModeGlyphPainter old) => old.mode != mode;
}
