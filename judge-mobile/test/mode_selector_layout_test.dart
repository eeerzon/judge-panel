import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/admin/admin_store.dart';
import 'package:kreen_judge_mobile/screens/mode_selector_screen.dart';
import 'package:kreen_judge_mobile/state/app_scope.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';
import 'package:kreen_judge_mobile/theme/tokens.dart';

import 'support/fake_judge_api.dart';

void main() {
  // Cards are always side by side in a Row; check wide and narrow screens lay
  // out cleanly (a Spacer inside the scroll view once threw "RenderBox was
  // not laid out").
  for (final size in [const Size(1280, 800), const Size(740, 360), const Size(400, 800)]) {
    testWidgets('mode selector lays out at ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeJudgeApi();
      final session = SessionStore.memory(api);
      await session.login('owner@test.com', 'password123');
      await tester.pumpWidget(AppScope(
        judge: JudgeStore(api),
        session: session,
        admin: AdminStore.memory(),
        child: MaterialApp(theme: buildAppTheme(), home: const ModeSelectorScreen()),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Open Admin'), findsOneWidget);
      expect(find.text('Open Judge Mode'), findsOneWidget);
      final admin = tester.getRect(find.text('ADMIN MODE'));
      final judge = tester.getRect(find.text('JUDGE MODE'));
      expect(admin.right < judge.left, isTrue, reason: 'Admin left of Judge (Row)');
      expect((admin.top - judge.top).abs() < 1, isTrue, reason: 'same row');
    });
  }
}
