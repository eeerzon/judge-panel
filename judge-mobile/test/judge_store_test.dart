import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/api/api_client.dart';
import 'package:kreen_judge_mobile/domain/models.dart';
import 'package:kreen_judge_mobile/state/judge_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_judge_api.dart';

const r = FakeJudgeApi.roundId;

void main() {
  late FakeJudgeApi api;
  late JudgeStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = FakeJudgeApi();
    store = JudgeStore(api, await SharedPreferences.getInstance(), Duration.zero)..bindJudge('282');
    await store.ensureRound(r);
  });

  tearDown(() => store.dispose());

  test('criteria become sections: parent heading + standalone sections', () {
    final sections = store.data(r)!.sections;
    expect(sections.map((s) => s.heading), ['Interview', 'Evening Gown', 'Stage Presence']);
    expect(sections.first.weight, 30);
    expect(sections.first.criteria.map((c) => c.label), ['Communication', 'Confidence', 'Substance']);
    expect(sections[1].criteria.single.standalone, isTrue);
    expect(sections.first.criteria[1].quickScore, [7, 8, 9, 10]);
  });

  test('FR-2 total matches the documented example (90.00) and is null while incomplete', () {
    final values = {101: 8.75, 102: 9.0, 103: 8.5, 104: 9.25};
    values.forEach((k, v) => store.setScore(r, 11, k, v));
    expect(store.calculateContestantTotal(r, 11), isNull);
    expect(store.getContestantStatus(r, 11).label, 'Draft · 4 / 5 criteria');
    store.setScore(r, 11, 105, 9.0);
    expect(store.calculateContestantTotal(r, 11), closeTo(90.0, 1e-9));
  });

  test('0–100 criterion scale (as on the live server) totals out of 100', () async {
    final hundred = JudgeStore(_HundredApi(), null, Duration.zero)..bindJudge('1');
    await hundred.ensureRound(r);
    final c = hundred.data(r)!.criteria.single;
    expect((c.min, c.max, c.step), (0.0, 100.0, 1.0));
    hundred.setScore(r, 11, 38, 80);
    expect(hundred.calculateContestantTotal(r, 11), closeTo(80, 1e-9));
    hundred.dispose();
  });

  test('edits are sent as one batch per contestant with the note as comment', () async {
    store.setScore(r, 11, 101, 8);
    store.setNote(r, 11, 'Great poise');
    expect(store.saveIndicator(r, 11), SaveIndicator.saving);
    await store.flush(r);
    expect(api.saved.last.map((s) => (s.criterionId, s.rawScore, s.comment)), [(101, 8.0, 'Great poise')]);
    expect(store.saveIndicator(r, 11), SaveIndicator.saved);
    expect(store.hasPending(r), isFalse);
  });

  test('offline save keeps the draft on device, survives restart, then syncs', () async {
    api.failNetwork = 1;
    store.setScore(r, 12, 104, 9.5);
    await store.flush(r);
    expect(store.syncState, SyncState.offline);
    expect(store.saveIndicator(r, 12), SaveIndicator.savedOnDevice);

    // "Restart": a new store for the same judge reloads the draft over server data.
    final again = JudgeStore(api, await SharedPreferences.getInstance(), Duration.zero)..bindJudge('282');
    await again.ensureRound(r);
    expect(again.getScore(r, 12, 104), 9.5);
    expect(again.hasPending(r), isTrue);
    await again.flush(r);
    expect(api.sheet[12]![104], 9.5);
    expect(again.hasPending(r), isFalse);
    again.dispose();
  });

  test('submit is refused while incomplete', () async {
    expect(await store.submitJudging(r), 'Complete all contestants before submitting.');
    expect(api.submitKeys, isEmpty);
  });

  test('submit retries with the same idempotency key, then locks the sheet', () async {
    for (final cid in [11, 12, 13]) {
      for (final k in [101, 102, 103, 104, 105]) {
        store.setScore(r, cid, k, 8);
      }
    }
    api.failNetwork = 0;
    await store.flush(r);

    api.failNextWith = null;
    api.failNetwork = 1; // the submit call itself fails ambiguously
    expect(await store.submitJudging(r), isNotNull);
    expect(await store.submitJudging(r), isNull);
    expect(api.submitKeys.length, 2);
    expect(api.submitKeys[0], api.submitKeys[1]);

    expect(store.isSubmitted(r), isTrue);
    expect(store.setScore(r, 11, 101, 10), isFalse);
    expect(store.getScore(r, 11, 101), 8);
  });

  test('submit right after an edit waits for the autosave in flight', () async {
    for (final cid in [11, 12, 13]) {
      for (final k in [101, 102, 103, 104, 105]) {
        store.setScore(r, cid, k, 8);
      }
    }
    await store.flush(r);
    api.saveGate = Completer<void>();
    store.setScore(r, 11, 101, 9);
    await Future<void>.delayed(Duration.zero); // the debounced autosave starts and blocks
    final submit = store.submitJudging(r);
    await Future<void>.delayed(Duration.zero);
    api.saveGate!.complete();
    expect(await submit, isNull);
    expect(store.isSubmitted(r), isTrue);
    expect(api.sheet[11]![101], 9);
  });

  test('server-locked sheet (422) drops the unsendable draft after reconcile', () async {
    store.setScore(r, 11, 101, 7);
    api.sheetStatus = 'submitted';
    api.failNextWith = const ApiException('Nilai peserta ini sudah disubmit dan terkunci.', statusCode: 422);
    await store.flush(r);
    expect(store.syncState, SyncState.error);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(store.isContestantLocked(r, 11), isTrue);
    expect(store.hasPending(r), isFalse);
  });

  test('event name follows the opened round (a judge may have rounds of several events)', () async {
    store.rounds = [
      ...await api.rounds(), // the app always has the rounds list (My Rounds)
      const Round(id: 8, name: 'Final', status: RoundStatus.open, eventId: 'v2', eventName: 'Ketapang Ethnic Day'),
    ];
    expect(store.eventName(r), 'King & Queen of the Pacific');
    expect(store.eventName(8), 'Ketapang Ethnic Day');
  });

  test('closed round cannot be scored', () async {
    api.status = RoundStatus.closed;
    await store.ensureRound(r, force: true);
    expect(store.canJudgeRound(r), isFalse);
    expect(store.setScore(r, 11, 101, 9), isFalse);
  });
}

class _HundredApi extends FakeJudgeApi {
  @override
  Future<List<Criterion>> criteria(int roundId) async => [
        Criterion.fromJson(
            {'id': 38, 'name': 'A', 'min_points': 0, 'max_points': 100, 'weight': '100.00', 'is_scored': true}),
      ];
}
