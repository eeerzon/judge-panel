import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/main.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';
import 'package:kreen_judge_mobile/theme/appearance.dart';
import 'package:kreen_judge_mobile/theme/tokens.dart';
import 'package:kreen_judge_mobile/widgets/appearance_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_judge_api.dart';

void main() {
  tearDown(() => AppColors.palette = AppPalette.kreen);

  test('light palette: dark text on light surfaces; status text darker for contrast', () {
    AppColors.palette = AppPalette.kreenLight;
    expect(AppColors.light, isTrue);
    expect(AppColors.textPrimary.computeLuminance(), lessThan(0.05));
    expect(AppColors.surface.computeLuminance(), greaterThan(0.9));
    expect(AppColors.statusErrorColor, const Color(0xFFB2412C));
    expect(AppColors.statusScoredFill, const Color(0xFF1E9E5C)); // the solid fill never changes
    final blue = AppPalette.fromHue(224, light: true);
    expect((blue.light, blue.textPrimary), (true, AppPalette.kreenLight.textPrimary));
    expect(HSLColor.fromColor(blue.accent).hue, closeTo(224, 1));
  });

  test('the choice is kept on the device', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppearanceStore.load();
    expect(store.light, isTrue); // light by default
    store.toggle();
    expect((await AppearanceStore.load()).light, isFalse); // night, kept after a restart
  });

  testWidgets('the toggle switches the open page to light mode and back', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await session.login('owner@test.com', 'password123');
    final appearance = AppearanceStore();
    await tester.pumpWidget(KreenJudgeApp(judge: JudgeStore(api), session: session, appearance: appearance));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(AppColors.light, isFalse);

    // Mode Selector: the round icon button.
    await tester.tap(find.byType(AppearanceIconButton));
    await tester.pumpAndSettle();
    expect((appearance.light, AppColors.light), (true, true));
    expect(find.text('Choose how you want to continue'), findsOneWidget); // same page, re-opened

    // Judge Mode header: the pill toggle.
    await tester.tap(find.text('Open Judge Mode'));
    await tester.pumpAndSettle();
    expect(AppColors.light, isTrue);
    await tester.tap(find.byType(AppearanceToggle));
    await tester.pumpAndSettle();
    expect((appearance.light, AppColors.light), (false, false));
    expect(find.text('Choose an assigned round to begin or continue judging.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
