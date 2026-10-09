import 'dart:async';

import 'package:kreen_judge_mobile/api/api_client.dart';
import 'package:kreen_judge_mobile/api/judge_api.dart';
import 'package:kreen_judge_mobile/domain/models.dart';

/// In-memory stand-in for the judge API: one open "Preliminary" round with
/// the prototype rubric (1–10, weights 10/10/10/30/40) and 3 contestants.
class FakeJudgeApi implements JudgeApi {
  FakeJudgeApi() {
    for (final c in contestantsJson) {
      sheet[c['id'] as int] = {for (final k in criteriaJson) k['id'] as int: null};
    }
  }

  static const roundId = 7;

  RoundStatus status = RoundStatus.open;

  /// `vote.banner` in the rounds list.
  String? bannerUrl;

  /// `vote.theme` in the rounds list (live shape; `source: "vote"` = none chosen).
  Map<String, dynamic> voteTheme = {'source': 'vote', 'id': 0, 'name': 'default', 'primary': '235,46,46', 'icon': '235,46,46'};
  bool resultsVisible = false;
  final Map<int, Map<int, double?>> sheet = {};
  final Map<int, String?> comments = {};
  final List<List<ScoreInput>> saved = [];
  final List<String> submitKeys = [];
  String sheetStatus = 'not_started';

  /// Next N saves/submits fail as if offline.
  int failNetwork = 0;
  ApiException? failNextWith;

  /// When set, saves wait for it (an autosave still in flight).
  Completer<void>? saveGate;

  static final criteriaJson = [
    {'id': 100, 'name': 'Interview', 'is_scored': false, 'weight': '0', 'min_points': 0, 'max_points': 0, 'parent_id': null},
    {'id': 101, 'name': 'Communication', 'is_scored': true, 'weight': '10.00', 'min_points': 1, 'max_points': 10, 'parent_id': 100},
    {'id': 102, 'name': 'Confidence', 'is_scored': true, 'weight': '10.00', 'min_points': 1, 'max_points': 10, 'parent_id': 100},
    {'id': 103, 'name': 'Substance', 'is_scored': true, 'weight': '10.00', 'min_points': 1, 'max_points': 10, 'parent_id': 100},
    {'id': 104, 'name': 'Evening Gown', 'is_scored': true, 'weight': '30.00', 'min_points': 1, 'max_points': 10, 'parent_id': null},
    {'id': 105, 'name': 'Stage Presence', 'is_scored': true, 'weight': '40.00', 'min_points': 1, 'max_points': 10, 'parent_id': null, 'step': '0.25'},
  ];

  static final contestantsJson = [
    for (final (id, no, name) in [(11, 1, 'Mrs Shaida'), (12, 2, 'Miss Yuka'), (13, 3, 'Mister Jerome')])
      {
        'id': id,
        'round_id': roundId,
        'id_finalis': 'f$id',
        'status': 'active',
        'finalis': {'id_finalis': 'f$id', 'nama_finalis': name, 'nomor_urut': no, 'profesi': 'Model', 'poster_finalis': null},
      },
  ];

  Map<String, dynamic> get _roundJson => {
        'id': roundId,
        'name': 'Preliminary',
        'order_no': 1,
        'status': status.name,
        'result_visibility': resultsVisible,
        'created_at': '2026-09-24T07:14:12.000000Z',
        'vote': {'id_vote': 'v1', 'judul_vote': 'King & Queen of the Pacific', 'theme': voteTheme, 'banner': bannerUrl},
      };

  void _maybeFail() {
    if (failNetwork > 0) {
      failNetwork--;
      throw const ApiException.network();
    }
    final e = failNextWith;
    if (e != null) {
      failNextWith = null;
      throw e;
    }
  }

  @override
  Future<LoginResult> login(String email, String password) async {
    if (password != 'password123') throw const ApiException('Email atau password salah.', statusCode: 401);
    return LoginResult(
      accessToken: 'token-$email',
      expiresIn: const Duration(hours: 1),
      judge: JudgeProfile(id: '282', name: 'Juri Free Satu', email: email),
      // owner@… → Admin + Judge, eventadmin@… → Admin only, else judge.
      actorType: email.startsWith('owner')
          ? ActorType.owner
          : email.startsWith('eventadmin')
              ? ActorType.admin
              : ActorType.judge,
    );
  }

  @override
  Future<List<Round>> rounds() async => [Round.fromJson(_roundJson)];

  @override
  Future<Round> round(int roundId) async => Round.fromJson(_roundJson..remove('vote'));

  @override
  Future<List<Contestant>> contestants(int roundId) async => contestantsJson.map(Contestant.fromJson).toList();

  @override
  Future<List<Criterion>> criteria(int roundId) async => criteriaJson.map(Criterion.fromJson).toList();

  @override
  Future<List<ScoreSheetRow>> scoreSheet(int roundId) async => [
        for (final c in contestantsJson)
          ScoreSheetRow.fromJson({
            'round_contestant_id': c['id'],
            'nama_finalis': (c['finalis'] as Map)['nama_finalis'],
            'sheet_status': sheetStatus,
            'scores': [
              for (final e in sheet[c['id']]!.entries)
                if (e.value != null)
                  {'round_criteria_id': e.key, 'raw_score': e.value, 'comment': comments[c['id']]},
            ],
          }),
      ];

  @override
  Future<void> saveScores(int roundId, List<ScoreInput> scores) async {
    await saveGate?.future;
    _maybeFail();
    saved.add(scores);
    for (final s in scores) {
      sheet[s.contestantId]![s.criterionId] = s.rawScore;
      comments[s.contestantId] = s.comment;
    }
  }

  @override
  Future<List<ScoreSheetRow>> review(int roundId) => scoreSheet(roundId);

  @override
  Future<void> submit(int roundId, String idempotencyKey) async {
    submitKeys.add(idempotencyKey);
    _maybeFail();
    sheetStatus = 'submitted';
  }

  @override
  Future<ResultSnapshot> results(int roundId) async {
    if (!resultsVisible) {
      throw const ApiException('Hasil ronde ini belum ditampilkan oleh admin.', statusCode: 403);
    }
    return const ResultSnapshot(isFinal: true);
  }

  void fillAll(double value) {
    for (final row in sheet.values) {
      row.updateAll((_, _) => value);
    }
  }
}
