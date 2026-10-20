import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kreen_judge_mobile/api/api_client.dart';
import 'package:kreen_judge_mobile/main.dart';
import 'package:kreen_judge_mobile/public/public_results.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';
import 'package:kreen_judge_mobile/theme/tokens.dart';

import 'support/fake_judge_api.dart';

/// `GET /judge/public/events/{slug}/results?round=1` (shape as captured on
/// 2026-10-13, trimmed to 3 finalists, 2 criteria and 2 judges).
Map<String, dynamic> _finalist(int rank, int number, double avg, String? profesi, List<List<double>> scores) => {
      'rank': rank,
      'finalis': {'id_finalis': 'f$number', 'nama_finalis': 'Finalis $number', 'nomor_urut': number, 'profesi': profesi, 'poster_finalis': null},
      'avg_score': avg,
      'accumulated_score': null,
      'criteria': [
        for (final (i, c) in [('TEKNIK POSE', 300, 30), ('TEKNIK CATWALK', 400, 40)].indexed)
          {
            'name': c.$1,
            'max_points': c.$2,
            'weight': c.$3,
            'scores': [
              for (final (j, s) in scores[i].indexed) {'juri': 'Juri ${j + 1}', 'raw_score': s * 10, 'score': s},
            ],
          },
      ],
      'juri_totals': [
        for (var j = 0; j < scores.first.length; j++) {'juri': 'Juri ${j + 1}', 'total_score': scores[0][j] + scores[1][j]},
      ],
    };

final _round1 = {
  'success': true,
  'data': {
    'event': {'judul_vote': 'Testing Stripe Auto', 'slug': 'testing_stripe_auto', 'banner': null},
    'round': {
      'id': 'r1',
      'name': 'Top 5',
      'order_no': 1,
      'status': 'finalized',
      'is_final': true,
      'finalis': [
        _finalist(1, 7, 4.44, 'Profesi 7', [[1.43, 1.42], [3.01, 3.02]]),
        _finalist(2, 3, 4.31, 'Profesi 3', [[1.39, 1.38], [2.92, 2.93]]),
        _finalist(2, 6, 4.31, null, [[1.40, 1.41], [2.91, 2.90]]),
      ],
    },
  },
};

/// Round 2 is still being judged: no scores.
final _round2Open = {
  'success': true,
  'message': 'Ronde ini sedang dalam masa penjurian.',
  'data': {
    'state': 'in_judging',
    'event': {'judul_vote': 'Testing Stripe Auto', 'slug': 'testing_stripe_auto', 'banner': null},
    'round': {'name': 'Penjurian', 'order_no': 2, 'status': 'open'},
  },
};

PublicResultsApi _api() => HttpPublicResultsApi(ApiClient(
      baseUrl: 'https://x',
      httpClient: MockClient((req) async {
        expect(req.headers['Authorization'], isNull); // public: never the session's token
        if (!req.url.path.contains('/judge/public/events/testing_stripe_auto/')) {
          return http.Response(jsonEncode({'message': 'Event tidak ditemukan.'}), 404);
        }
        return switch (req.url.queryParameters['round']) {
          '1' => http.Response(jsonEncode(_round1), 200),
          '2' => http.Response(jsonEncode(_round2Open), 200),
          _ => http.Response(jsonEncode({'message': 'Tidak ada ronde yang tersedia.'}), 404), // draft / no such round
        };
      }),
    ));

void main() {
  late PublicResultsApi original;
  setUp(() {
    original = PublicResultsApi.instance;
    PublicResultsApi.instance = _api();
  });
  tearDown(() {
    PublicResultsApi.instance = original;
    AppColors.palette = AppPalette.kreen;
  });

  test('route: /<slug>/round_<n> only', () {
    expect(parsePublicResultsRoute('/testing_votingme_laravel_13/round_2'), (slug: 'testing_votingme_laravel_13', orderNo: 2));
    expect(parsePublicResultsRoute('/my-event/round_1/'), (slug: 'my-event', orderNo: 1));
    for (final other in ['/rounds', '/login', '/admin/round_1', '/x/round_0', '/x/round_a', '/x/y/round_1', null]) {
      expect(parsePublicResultsRoute(other), isNull, reason: other);
    }
  });

  test('parses the endpoint: judge totals, weighted score per criterion, shared ranks', () async {
    final result = await PublicResultsApi.instance.roundResult('testing_stripe_auto', 1);
    expect((result.published, result.roundName, result.eventName), (true, 'Top 5', 'Testing Stripe Auto'));
    expect(result.criteria.map((c) => (c.name, c.maxPoints)), [('TEKNIK POSE', 30.0), ('TEKNIK CATWALK', 40.0)]);
    final first = result.items.first;
    expect((first.rank, first.number, first.name, first.additionalName, first.finalScore), (1, 7, 'Finalis 7', 'Profesi 7', 4.44));
    expect(first.judges.map((j) => j.total), [closeTo(4.44, 1e-9), closeTo(4.44, 1e-9)]);
    expect(first.judges[1].scores, {'TEKNIK POSE': 1.42, 'TEKNIK CATWALK': 3.02});
    expect(result.items.map((i) => i.tied), [false, true, true]);
  });

  test('open round → not published, with its name; draft / missing round and unknown event → 404', () async {
    final open = await PublicResultsApi.instance.roundResult('testing_stripe_auto', 2);
    expect((open.published, open.roundName, open.eventName), (false, 'Penjurian', 'Testing Stripe Auto'));
    for (final (slug, round) in [('testing_stripe_auto', 4), ('nope', 1)]) {
      await expectLater(
        PublicResultsApi.instance.roundResult(slug, round),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    }
  });

  Future<void> open(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.defaultRouteNameTestValue = route;
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    final api = FakeJudgeApi();
    // Nobody signed in: the link must still open.
    await tester.pumpWidget(KreenJudgeApp(judge: JudgeStore(api), session: SessionStore.memory(api)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('finalized round: cards with each judge total; tap shows the criteria', (tester) async {
    await open(tester, '/testing_stripe_auto/round_1');
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Top 5'), findsOneWidget);
    expect(find.text('Nilai Akhir'), findsNWidgets(3));
    expect(find.text('SERI'), findsNWidgets(2));
    expect(find.text('KRITERIA'), findsNothing);

    await tester.tap(find.text('#07'));
    await tester.pumpAndSettle();
    expect(find.text('KRITERIA'), findsOneWidget);
    expect(find.text('TEKNIK POSE (maks 30)'), findsOneWidget);
    // Judges are numbered, never named.
    expect(find.text('JURI 1'), findsOneWidget);
    expect(find.text('JURI 2'), findsOneWidget);

    await tester.tap(find.text('#07'));
    await tester.pumpAndSettle();
    expect(find.text('KRITERIA'), findsNothing);
  });

  testWidgets('round still being judged: in-progress notice, no scores', (tester) async {
    await open(tester, '/testing_stripe_auto/round_2');
    expect(find.text('Penjurian masih berlangsung'), findsOneWidget);
    expect(find.byIcon(Icons.engineering_rounded), findsOneWidget);
    expect(find.text('Nilai Akhir'), findsNothing);
  });

  testWidgets('draft or missing round, unknown event: not found', (tester) async {
    for (final route in ['/testing_stripe_auto/round_4', '/slug_tidak_ada/round_1']) {
      await open(tester, route);
      expect(find.text('Halaman tidak ditemukan'), findsOneWidget, reason: route);
      expect(find.text('Muat Ulang'), findsNothing);
    }
  });

  test('judge labels: "Juri" for a single judge, numbered otherwise', () {
    PublicJudgeScore judge(String label) => PublicJudgeScore(label: label, total: 0, scores: const {});
    expect(publicJudgeLabel(judge('Juri 1'), 0, 1), 'Juri');
    expect(publicJudgeLabel(judge('Juri 2'), 1, 3), 'Juri 2');
    expect(publicJudgeLabel(judge(''), 2, 3), 'Juri 3');
  });
}
