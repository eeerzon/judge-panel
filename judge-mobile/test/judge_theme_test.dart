import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/main.dart';
import 'package:kreen_judge_mobile/navigation/judge_nav.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';
import 'package:kreen_judge_mobile/theme/judge_theme.dart';
import 'package:kreen_judge_mobile/theme/tokens.dart';
import 'package:kreen_judge_mobile/widgets/themed_background.dart';
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

  test('API theme list parses "r,g,b"; id 0 "default" is red (as the API), with its background picture', () {
    final t = EventTheme.fromApi({'id': 0, 'name': 'default', 'primary': '235,46,46', 'icon': '235,46,46'})!;
    expect((t.name, t.isDefault), ('Default', true));
    expect(HSLColor.fromColor(t.palette.accent).hue, closeTo(0, 1)); // red, not the KREEN gold
    expect(t.backgroundUrl, 'https://dev.kreenconnect.com/image/vote/bg-vote-default.jpg');
    expect(theme(6).backgroundUrl, 'https://dev.kreenconnect.com/image/vote/bg-vote-6.jpg');
    expect(EventTheme.fromApi({'id': 1, 'name': 'Blue', 'primary': '41,69,143'})!.primary, const Color(0xFF29458F));
    expect(EventTheme.fromApi({'id': 9, 'name': 'x', 'primary': 'bad'}), isNull);
  });

  test('server theme per event: the choice, else the vote\'s own theme; cached on the device', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await JudgeThemeStore.load();
    const web = {'source': 'vote', 'id': 0, 'name': 'default', 'primary': '235,46,46', 'icon': '235,46,46'};
    const green = {'source': 'judge', 'id': 3, 'name': 'Green', 'primary': '0,143,95', 'icon': '134, 229, 198'};
    store.syncFromRounds([(eventId: 'v1', theme: web), (eventId: 'v2', theme: green), (eventId: 'v3', theme: null)]);
    expect(store.themeIdFor('v1'), 0); // not chosen: the vote's own (Default, red)
    expect(store.themeIdFor('v2'), 3);
    expect(store.themeIdFor('v3'), isNull); // no theme known → KREEN
    expect((await JudgeThemeStore.load()).paletteFor(['v2']).accent, theme(3).palette.accent); // offline, after restart
    expect(store.paletteFor(['v1', 'v2']).accent, AppPalette.kreen.accent); // mixed events
    store.syncFromRounds([(eventId: 'v2', theme: web)]);
    expect(store.themeIdFor('v2'), 0);
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
    // Mode Selector: Default picture (no event theme); Login has none.
    expect(tester.widget<ThemedBackground>(find.byType(ThemedBackground)).url, EventTheme.backgroundUrlFor(0));

    await tester.tap(find.text('Open Judge Mode'));
    await tester.pumpAndSettle();
    expect(AppColors.palette.accent, theme(1).palette.accent); // My Rounds
    await tester.tap(find.text('Enter Round'));
    await tester.pumpAndSettle();
    expect(find.text('Contestants'), findsOneWidget);
    expect(AppColors.palette.accent, theme(1).palette.accent); // Contestants
    // The theme picture under a dark tint; scaffolds are see-through over it.
    expect(tester.widget<ThemedBackground>(find.byType(ThemedBackground)).url, theme(1).backgroundUrl);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(Theme.of(tester.element(find.byWidget(scaffold))).scaffoldBackgroundColor, Colors.transparent);

    Navigator.of(tester.element(find.text('Contestants'))).pushReplacementNamed(Routes.modeSelector);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(AppColors.palette.accent, AppPalette.kreen.accent);
  });
}
