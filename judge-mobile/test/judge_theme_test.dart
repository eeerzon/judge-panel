import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/main.dart';
import 'package:kreen_judge_mobile/navigation/judge_nav.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';
import 'package:kreen_judge_mobile/theme/judge_theme.dart';
import 'package:kreen_judge_mobile/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_judge_api.dart';

EventTheme theme(int id) => EventTheme.builtIn.firstWhere((t) => t.id == id);

void main() {
  tearDown(() => AppColors.palette = AppPalette.kreen);

  test('theme palette keeps contrast: accents keep the KREEN luminance, status colours never change', () {
    final blue = theme(1).palette;
    const k = AppPalette.kreen;
    for (final (a, b) in [(blue.accent, k.accent), (blue.accentBright, k.accentBright), (blue.textSecondary, k.textSecondary)]) {
      expect(a.computeLuminance(), closeTo(b.computeLuminance(), 0.005));
    }
    expect(HSLColor.fromColor(blue.accent).hue, closeTo(theme(1).hue, 1));
    expect(HSLColor.fromColor(blue.bgBase).lightness, closeTo(HSLColor.fromColor(k.bgBase).lightness, 0.01));
    AppColors.palette = blue;
    expect(AppColors.statusScoredFill, const Color(0xFF1E9E5C));
    expect(AppColors.accent, blue.accent);
  });

  test('API theme list parses "r,g,b"; id 0 "default" is the KREEN default', () {
    final t = EventTheme.fromApi({'id': 0, 'name': 'default', 'primary': '235,46,46', 'icon': '235,46,46'})!;
    expect((t.name, t.isKreen, t.palette.accent), ('KREEN', true, AppPalette.kreen.accent));
    expect(EventTheme.fromApi({'id': 1, 'name': 'Blue', 'primary': '41,69,143'})!.primary, const Color(0xFF29458F));
    expect(EventTheme.chosenFrom({'source': 'judge', 'id': 0, 'name': 'default', 'primary': '235,46,46'}), isNull);
    expect(EventTheme.fromApi({'id': 9, 'name': 'x', 'primary': 'bad'}), isNull);
  });

  test('server theme per event: source "vote" = none chosen; cached on the device for offline', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await JudgeThemeStore.load();
    const web = {'source': 'vote', 'id': 0, 'name': 'default', 'primary': '235,46,46', 'icon': '235,46,46'};
    const green = {'source': 'judge', 'id': 3, 'name': 'Green', 'primary': '0,143,95', 'icon': '134, 229, 198'};
    store.syncFromRounds([(eventId: 'v1', theme: web), (eventId: 'v2', theme: green), (eventId: 'v3', theme: null)]);
    expect(store.themeIdFor('v1'), isNull); // the vote's web theme is not a Judge Mode choice
    expect(store.paletteFor(['v1']).accent, AppPalette.kreen.accent);
    expect(store.themeIdFor('v2'), 3);
    expect((await JudgeThemeStore.load()).paletteFor(['v2']).accent, theme(3).palette.accent); // offline, after restart
    expect(store.paletteFor(['v1', 'v2']).accent, AppPalette.kreen.accent); // mixed events
    store.syncFromRounds([(eventId: 'v2', theme: web)]); // admin cleared it
    expect(store.themeIdFor('v2'), isNull);
  });

  testWidgets('Judge Mode pages use the event theme; Login/Mode Selector keep KREEN', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final themes = await JudgeThemeStore.load();

    // The admin chose Blue: /judge/rounds → vote.theme.
    final api = FakeJudgeApi()
      ..voteTheme = {'source': 'judge', 'id': 1, 'name': 'Blue', 'primary': '41,69,143', 'icon': '150, 179, 255'};
    final session = SessionStore.memory(api);
    await session.login('juri1.free@test.com', 'password123');
    await tester.pumpWidget(KreenJudgeApp(judge: JudgeStore(api), session: session, themes: themes));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(AppColors.palette.accent, AppPalette.kreen.accent); // Mode Selector

    await tester.tap(find.text('Open Judge Mode'));
    await tester.pumpAndSettle();
    expect(AppColors.palette.accent, theme(1).palette.accent); // My Rounds
    await tester.tap(find.text('Enter Round'));
    await tester.pumpAndSettle();
    expect(find.text('Contestants'), findsOneWidget);
    expect(AppColors.palette.accent, theme(1).palette.accent); // Contestants
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(Theme.of(tester.element(find.byWidget(scaffold))).scaffoldBackgroundColor, theme(1).palette.bgBase);

    Navigator.of(tester.element(find.text('Contestants'))).pushReplacementNamed(Routes.modeSelector);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(AppColors.palette.accent, AppPalette.kreen.accent);
  });
}
