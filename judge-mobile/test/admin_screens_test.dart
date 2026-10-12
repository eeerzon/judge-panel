import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/admin/admin_nav.dart';
import 'package:kreen_judge_mobile/admin/admin_store.dart';
import 'package:kreen_judge_mobile/navigation/judge_nav.dart';
import 'package:kreen_judge_mobile/state/app_scope.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';
import 'package:kreen_judge_mobile/theme/tokens.dart';

import 'support/fake_judge_api.dart';

/// Every Admin page, rendered in the prototype's reference sizes:
/// tablet landscape (sidebar), narrow landscape (208px sidebar), phone
/// landscape (bottom bar) — no layout exceptions allowed.
void main() {
  final pages = <(String, Object?)>[
    (AdminRoutes.overview, null),
    (AdminRoutes.rounds, null),
    (AdminRoutes.contestants, null),
    (AdminRoutes.judges, null),
    (AdminRoutes.live, null),
    (AdminRoutes.results, null),
    (AdminRoutes.settings, null),
    (AdminRoutes.audit, null),
    (AdminRoutes.roundOverview, const AdminRoundArgs('1')),
    (AdminRoutes.roundOverview, const AdminRoundArgs('2')),
    (AdminRoutes.monitoring, const AdminRoundArgs('1')),
    (AdminRoutes.submission, const AdminRoundArgs('1', judgeId: '3')),
    (AdminRoutes.roundContestants, const AdminRoundArgs('2')),
    (AdminRoutes.roundJudges, const AdminRoundArgs('1')),
    (AdminRoutes.criteria, const AdminRoundArgs('1')),
    (AdminRoutes.roundResults, const AdminRoundArgs('1')),
    (AdminRoutes.roundResults, const AdminRoundArgs('9')),
  ];

  for (final size in [const Size(1280, 800), const Size(1024, 700), const Size(852, 393), const Size(740, 390)]) {
    testWidgets('admin pages lay out at ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeJudgeApi();
      final session = SessionStore.memory(api);
      await session.login('owner@test.com', 'password123');
      final admin = AdminStore.memory();
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(AppScope(
        judge: JudgeStore(api),
        session: session,
        admin: admin,
        child: MaterialApp(
          navigatorKey: key,
          theme: buildAppTheme(),
          onGenerateRoute: JudgeNav.onGenerateRoute,
          onGenerateInitialRoutes: JudgeNav.onGenerateInitialRoutes,
          initialRoute: AdminRoutes.overview,
        ),
      ));
      await tester.pumpAndSettle();
      for (final (route, args) in pages) {
        key.currentState!.pushReplacementNamed(route, arguments: args);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route $args');
      }

      // Results + detail + advancement after running the lifecycle.
      admin.updateJudgeAssignment('1', '4', 'excuse', 'x');
      admin.updateJudgeAssignment('1', '5', 'excuse', 'x');
      admin.closeRound('1');
      for (final (route, args) in [
        (AdminRoutes.roundResults, const AdminRoundArgs('1')),
        (AdminRoutes.resultDetail, AdminRoundArgs('1', contestantId: admin.calculateRoundResults('1').items.first.contestantId)),
      ]) {
        key.currentState!.pushReplacementNamed(route, arguments: args);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      if (admin.calculateRoundResults('1').hasTie) admin.acknowledgeTie('1');
      admin.finalizeResults('1');
      key.currentState!.pushReplacementNamed(AdminRoutes.advancement, arguments: const AdminRoundArgs('1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'advancement');
      expect(find.text('10 / 10 selected'), findsOneWidget);
    });
  }

  testWidgets('drawer + governance modal: reopen requires a reason', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await session.login('owner@test.com', 'password123');
    final admin = AdminStore.memory();
    await tester.pumpWidget(AppScope(
      judge: JudgeStore(api),
      session: session,
      admin: admin,
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [
          JudgeNav.onGenerateRoute(const RouteSettings(name: AdminRoutes.monitoring, arguments: AdminRoundArgs('1'))),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ratih Pramesti'), findsOneWidget);
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(find.text('Reopen Submission'), findsOneWidget);
    await tester.tap(find.text('Reopen Submission'));
    await tester.pumpAndSettle();
    expect(find.text("Reopen Ratih Pramesti's submission?"), findsOneWidget);
    await tester.tap(find.text('Reopen Submission').last);
    await tester.pumpAndSettle();
    expect(find.text('Reason is required.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Score typo');
    await tester.tap(find.text('Reopen Submission').last);
    await tester.pumpAndSettle();
    expect(admin.getMonitoringJudges('1').first.submissionStatus, 'reopened');
    expect(tester.takeException(), isNull);
  });

  testWidgets('round chips sit in one row (Judges master, iPhone landscape)', (tester) async {
    tester.view.physicalSize = const Size(852, 393);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await session.login('owner@test.com', 'password123');
    await tester.pumpWidget(AppScope(
      judge: JudgeStore(api),
      session: session,
      admin: AdminStore.memory(),
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [JudgeNav.onGenerateRoute(const RouteSettings(name: AdminRoutes.judges))],
      ),
    ));
    await tester.pumpAndSettle();
    final pre = tester.getRect(find.text('Preliminary').first);
    final top = tester.getRect(find.text('Top 10').first);
    final fin = tester.getRect(find.text('Final').first);
    expect((pre.top - top.top).abs() < 1 && (top.top - fin.top).abs() < 1, isTrue, reason: 'same row');
    expect(pre.right < top.left && top.right < fin.left, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Selected tells how many contestants were added', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await session.login('owner@test.com', 'password123');
    final admin = AdminStore.memory();
    await tester.pumpWidget(AppScope(
      judge: JudgeStore(api),
      session: session,
      admin: admin,
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: JudgeNav.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [
          JudgeNav.onGenerateRoute(const RouteSettings(name: AdminRoutes.roundContestants, arguments: AdminRoundArgs('2'))),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Selected'));
    await tester.pumpAndSettle();
    expect(find.text('Select contestants first.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // message times out
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Selected'));
    await tester.pumpAndSettle();
    expect(find.text('15 contestants added to Top 10.'), findsOneWidget);
    expect(admin.getRoundContestants('2').length, 15);
    expect(tester.takeException(), isNull);
  });
}
