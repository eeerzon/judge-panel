// Login — 1:1 layout port of judge-prototype/index.html + entry.css, backed
// by `POST /judge/auth/login`. This app ships Judge Mode only, so the Mode
// Selector (mode.html) is skipped: a signed-in judge goes to My Rounds.
//
// Sizes follow entry.css, including its cascade quirk: `.entry-body button
// { font: inherit }` out-ranks `.entry-btn`, so "Sign In" renders 16px/400.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../widgets/appearance_toggle.dart';
import '../widgets/common.dart';

/// TEMPORARY: "Demo access" list of test accounts on the KREEN staging
/// server — one owner (Mode Selector → Admin / Judge) and judges (password
/// `password123`). Set to false — or remove the list — before a production
/// build.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identity = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _error = SessionScope.read(context).expiredMessage;
  }

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(String email, String password) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).login(email, password);
      if (mounted) JudgeNav.goToModeSelector(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) _signIn(_identity.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final vw = MediaQuery.sizeOf(context).width;
          final width = constraints.maxWidth;

          // .entry-layout: grid [minmax(0,1fr) minmax(380px,480px)], centred,
          // width min(1180px,100%), padding 56px clamp(24px,6vw,80px),
          // gap clamp(36px,7vw,110px).
          //
          // Always a Row — intro on the left, Sign-in panel on the right. The
          // app is landscape-only, so the prototype's stacked ≤760px variant
          // is not used; on narrow screens the columns shrink instead.
          final padX = (vw * 0.06).clamp(24.0, 80.0);
          final inner = width.clamp(0.0, 1180.0) - padX * 2;
          final gap = (vw * 0.07).clamp(36.0, 110.0);
          // Panel up to 480 (min 320 on small screens), intro keeps ≥ 260.
          final panelWidth = (inner - gap - 260).clamp(320.0, 480.0);

          // Web on a phone browser (portrait, narrow): the prototype's stacked
          // ≤760px variant — intro above the Sign-in panel. iOS / Android
          // stay landscape and keep the Row.
          final stacked = kIsWeb && width <= 760;
          final Widget content = stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Intro(vw: vw, compact: true),
                    const SizedBox(height: 32),
                    _panel(vw),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _Intro(vw: vw)),
                    SizedBox(width: gap),
                    SizedBox(width: panelWidth, child: _panel(vw)),
                  ],
                );

          return Stack(children: [
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: stacked
                          ? const EdgeInsets.fromLTRB(20, 72, 20, 40)
                          : EdgeInsets.symmetric(horizontal: padX, vertical: 56),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
            // Night / light mode, top right.
            const Positioned(top: 16, right: 16, child: AppearanceIconButton()),
          ]);
        }),
      ),
    );
  }

  Widget _panel(double vw) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );
    // .entry-panel input: 48px min-height, 0 14px padding, 16px inherited font.
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: ts(16, color: AppColors.textSecondary.withValues(alpha: 0.72)),
          filled: true,
          fillColor: AppColors.surfaceAlt,
          isDense: true,
          constraints: const BoxConstraints(minHeight: 48),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: border(AppColors.borderStrong),
          disabledBorder: border(AppColors.borderStrong),
          focusedBorder: border(AppColors.accent),
          errorBorder: border(AppColors.statusErrorColor),
          focusedErrorBorder: border(AppColors.statusErrorColor),
          errorStyle: ts(12, color: AppColors.statusErrorColor),
        );
    String? required(String? v) => (v == null || v.trim().isEmpty) ? 'Please fill out this field.' : null;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: ts(13, weight: FontWeight.w700)),
        );
    final pad = (vw * 0.03).clamp(26.0, 40.0);

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 55, offset: const Offset(0, 18))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('WELCOME BACK',
                style: ts(12, weight: FontWeight.w800, color: AppColors.accentBright, letterSpacingEm: 0.13)),
            const SizedBox(height: 7),
            Text('Sign in', style: ts(31, weight: FontWeight.w700, letterSpacingEm: -0.025, height: 1.2)),
            const SizedBox(height: 9),
            Text('Continue to your judging workspace.', style: ts(14, color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            label('Email or username'),
            TextFormField(
              controller: _identity,
              style: ts(16),
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: deco('Your email or username'),
              validator: required,
            ),
            const SizedBox(height: 18),
            label('Password'),
            TextFormField(
              controller: _password,
              style: ts(16),
              enabled: !_busy,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: deco('Enter password'),
              validator: required,
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: ts(13, color: AppColors.statusErrorColor)),
              ),
              const SizedBox(height: 14),
            ],
            AppButton(
              label: _busy ? 'Signing in…' : 'Sign In',
              trailing: Text('→', style: ts(16)),
              onTap: _busy ? null : _submit,
              disabledOpacity: 0.6,
              expand: true,
              height: 48,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.entry-intro` — left column of the Row.
class _Intro extends StatelessWidget {
  const _Intro({required this.vw, this.compact = false});
  final double vw;

  /// Phone browser (stacked layout): smaller heading.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // h1: clamp(38px, 4.4vw, 62px)
    final h1 = compact ? (vw * 0.09).clamp(30.0, 40.0) : (vw * 0.044).clamp(38.0, 62.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 550),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const KreenMark(),
          SizedBox(height: compact ? 20 : 28),
          Text('KREEN JUDGING',
              style: ts(12, weight: FontWeight.w800, color: AppColors.accentBright, letterSpacingEm: 0.17)),
          const SizedBox(height: 14),
          Text(
            'Every score starts with clarity.',
            style: ts(h1, weight: FontWeight.w700, letterSpacingEm: -0.04, height: 1.08),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'One place to manage the event and give every contestant a thoughtful, fair evaluation.',
              style: ts(16, color: AppColors.textSecondary, height: 1.6),
            ),
          ),
          // const SizedBox(height: 46),
          // Container(
          //   padding: const EdgeInsets.only(top: 16),
          //   decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          //   child: Text('King & Queen of the Pacific · 2026', style: ts(13, color: AppColors.textSecondary)),
          // ),
        ],
      ),
    );
  }
}

/// `.entry-mark` — the gold "K" tile.
class KreenMark extends StatelessWidget {
  const KreenMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.accentDeep),
      ),
      child: Text('K', style: ts(22, weight: FontWeight.w800, color: AppColors.accentBright)),
    );
  }
}