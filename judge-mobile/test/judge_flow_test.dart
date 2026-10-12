import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/domain/models.dart';
import 'package:kreen_judge_mobile/main.dart';
import 'package:kreen_judge_mobile/navigation/judge_nav.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';
import 'package:kreen_judge_mobile/widgets/appearance_toggle.dart';
import 'package:kreen_judge_mobile/widgets/themed_background.dart';
import 'package:kreen_judge_mobile/widgets/common.dart' show BackLink;

import 'support/fake_judge_api.dart';

/// Only on My Rounds (the page title is now the event name).
const kMyRoundsSubtitle = 'Choose an assigned round to begin or continue judging.';

void main() {
  testWidgets('login → my rounds → gallery (no Standby) → scoring saves to the API', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    final judge = JudgeStore(api);
    await tester.pumpWidget(KreenJudgeApp(judge: judge, session: session));
    await tester.pump();
    // Splash first (white + KREEN logo), then Login since there is no session.
    expect(find.image(const AssetImage('assets/images/KreenOriginal.png')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Login has no background picture, but has the night / light button.
    expect(find.byType(ThemedBackground), findsNothing);
    expect(find.byType(AppearanceIconButton), findsOneWidget);

    // Wrong password → server message is shown.
    await tester.enterText(find.byType(TextFormField).at(0), 'juri1.free@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'nope');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Email atau password salah.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // actor_type judge → Mode Selector with only the Judge card.
    expect(find.text('Choose how you want to continue'), findsOneWidget);
    expect(find.text('Open Admin'), findsNothing);
    await tester.tap(find.text('Open Judge Mode'));
    await tester.pumpAndSettle();
    expect(find.text(kMyRoundsSubtitle), findsOneWidget);
    expect(find.text('Switch to Admin Mode'), findsNothing);
    expect(find.text('KING & QUEEN OF THE PACIFIC'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    // Standby is hidden: Enter Round opens the gallery (spinner while loading).
    await tester.tap(find.text('Enter Round'));
    await tester.pumpAndSettle();
    expect(find.text('Tap anywhere to start'), findsNothing);
    expect(find.text('Standby'), findsNothing);
    expect(find.text('Contestants'), findsOneWidget);
    expect(find.text('Judge · Juri Free Satu'), findsOneWidget);
    expect(find.text('← My Rounds'), findsOneWidget); // direct way back to the round list
    // Touch target ≥ 48×48 (no misses on a physical tablet).
    final backSize = tester.getSize(find.byType(BackLink));
    expect(backSize.height, greaterThanOrEqualTo(48));
    expect(backSize.width, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Miss Yuka'));
    await tester.pumpAndSettle();

    expect(find.text('0 of 5 criteria scored'), findsOneWidget);
    // API details: additional name · profession · age, and the bio (clamped).
    expect(find.text('Yuka Tanaka · Model · 24 yrs'), findsOneWidget);
    expect(find.text('Read more'), findsOneWidget);
    await tester.ensureVisible(find.text('Read more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(find.text('#02 · Miss Yuka'), findsOneWidget); // full bio dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Manual entry never silent-rounds.
    await tester.tap(find.bySemanticsLabel(RegExp('Edit Communication score')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '8.33');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Use increments of 0.25.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '8.25');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1)); // debounce → POST score-sheet
    await tester.pumpAndSettle();
    expect(api.sheet['rc12']!['cr101'], 8.25);
    expect(find.text('Saved ✓'), findsOneWidget);
    expect(find.text('1 of 5 criteria scored'), findsOneWidget);

    await tester.tap(find.text('← Contestants'));
    await tester.pumpAndSettle();
    expect(find.text('Draft · 1 / 5 criteria'), findsOneWidget);

    // Back to the round list straight from the gallery (no Standby step).
    await tester.tap(find.text('← My Rounds'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    // Same rule as my-rounds.js: "In Progress" needs a fully scored contestant.
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('3 Contestants'), findsOneWidget);
    judge.dispose();
  });

  testWidgets('splash with a saved session → Mode Selector (owner: both, judge: Judge only)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await session.login('owner@test.com', 'password123');
    final judge = JudgeStore(api);
    await tester.pumpWidget(KreenJudgeApp(judge: judge, session: session));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Choose how you want to continue'), findsOneWidget);
    await tester.tap(find.text('Open Judge Mode'));
    await tester.pumpAndSettle();
    expect(find.text(kMyRoundsSubtitle), findsOneWidget);
    expect(find.text('Enter Round'), findsOneWidget);

    // A judge's saved session skips the Mode Selector.
    await tester.pumpWidget(const SizedBox());
    final judgeSession = SessionStore.memory(api);
    await judgeSession.login('juri1.free@test.com', 'password123');
    await tester.pumpWidget(KreenJudgeApp(judge: JudgeStore(api), session: judgeSession));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Choose how you want to continue'), findsOneWidget);
    expect(find.text('Open Judge Mode'), findsOneWidget);
    expect(find.text('Open Admin'), findsNothing);
    judge.dispose();
  });

  testWidgets('Mode Selector cards + route guards per actor_type', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await tester.pumpWidget(KreenJudgeApp(judge: JudgeStore(api), session: session));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'owner@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    // Owner: both workspaces.
    expect(find.text('Open Admin'), findsOneWidget);
    await tester.tap(find.text('Open Judge Mode'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to Admin Mode'), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    // Judge: Admin routes fall back to the Mode Selector (Judge card only).
    await session.logout();
    await tester.pumpAndSettle();
    await session.login('juri1@test.com', 'password123');
    nav.pushReplacementNamed(Routes.admin);
    await tester.pumpAndSettle();
    expect(find.text('Choose how you want to continue'), findsOneWidget);
    expect(find.text('Open Admin'), findsNothing);
    expect(find.text('Open Judge Mode'), findsOneWidget);

    // Admin: Admin card only; Judge routes fall back to the Mode Selector.
    await session.logout();
    await tester.pumpAndSettle();
    await session.login('eventadmin@test.com', 'password123');
    nav.pushReplacementNamed(Routes.modeSelector);
    await tester.pumpAndSettle();
    expect(find.text('Open Admin'), findsOneWidget);
    expect(find.text('Open Judge Mode'), findsNothing);
    nav.pushReplacementNamed(Routes.myRounds);
    await tester.pumpAndSettle();
    expect(find.text(kMyRoundsSubtitle), findsNothing);
    expect(find.text('Open Admin'), findsOneWidget);
    await tester.tap(find.text('Open Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to Judge Mode'), findsNothing);
    expect(find.text('← Switch to Judge Mode'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Log Out works with a session restored at start-up, also after it already lapsed', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await session.login('owner@test.com', 'password123'); // "saved" before the app starts
    await tester.pumpWidget(KreenJudgeApp(judge: JudgeStore(api), session: session));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);

    // Session ended elsewhere (e.g. 401) while an Admin page stays open.
    await session.login('owner@test.com', 'password123');
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pushReplacementNamed(Routes.admin);
    await tester.pumpAndSettle();
    await session.logout();
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired token (401): "Session expired" shows for a moment, then Login', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await session.login('owner@test.com', 'password123');
    await tester.pumpWidget(KreenJudgeApp(judge: JudgeStore(api), session: session));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Admin'));
    await tester.pumpAndSettle();

    session.handleUnauthorized(); // what ApiClient does on a 401
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Session expired'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing); // the page stays behind the notice
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Session expired'), findsNothing);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Your session has ended. Please sign in again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Rounds: one section per event, titled with the event name', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _TwoEventApi();
    final session = SessionStore.memory(api);
    await session.login('juri1@test.com', 'password123');
    await tester.pumpWidget(KreenJudgeApp(judge: JudgeStore(api), session: session));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Judge Mode'));
    await tester.pumpAndSettle();
    final first = tester.getRect(find.text('KING & QUEEN OF THE PACIFIC'));
    final second = tester.getRect(find.text('MISS KREEN 2026'));
    final firstRound = tester.getRect(find.text('Preliminary'));
    final secondRound = tester.getRect(find.text('Grand Final'));
    expect(first.top < firstRound.top && firstRound.top < second.top && second.top < secondRound.top, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _TwoEventApi extends FakeJudgeApi {
  @override
  Future<List<Round>> rounds() async => [
        ...await super.rounds(),
        Round.fromJson({
          'id': 90, 'id_vote': 'v2', 'name': 'Grand Final', 'order_no': 1, 'status': 'draft',
          'vote': {'id_vote': 'v2', 'judul_vote': 'Miss Kreen 2026'},
        }),
      ];
}
