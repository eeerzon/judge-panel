import 'dart:async';

import 'package:kreen_judge_mobile/api/api_client.dart';
import 'package:kreen_judge_mobile/api/judge_api.dart';
import 'package:kreen_judge_mobile/domain/models.dart';

/// In-memory stand-in for the judge API: one open "Preliminary" round with
/// the prototype rubric (1–10, weights 10/10/10/30/40) and 3 contestants.
/// Ids are non-numeric strings, like the live server's hashes since
/// 2026-10-09 (round `r7`, round contestants `rc11`…, criteria `cr100`…).
class FakeJudgeApi implements JudgeApi {
  FakeJudgeApi() {
    for (final c in contestantsJson) {
      sheet[c['id'] as String] = {for (final k in criteriaJson) k['id'] as String: null};
    }
  }

  static const roundId = 'r7';

  RoundStatus status = RoundStatus.open;

  /// `vote.banner` in the rounds list.
  String? bannerUrl;

  /// `vote.theme` in the rounds list (live shape; `source: "vote"` = none chosen).
  Map<String, dynamic> voteTheme = {'source': 'vote', 'id': 0, 'name': 'default', 'primary': '235,46,46', 'icon': '235,46,46'};
  bool resultsVisible = false;
  final Map<String, Map<String, double?>> sheet = {};
  final Map<String, String?> comments = {};
  final List<List<ScoreInput>> saved = [];
  final List<String> submitKeys = [];
  String sheetStatus = 'not_started';

  /// Next N saves/submits fail as if offline.
  int failNetwork = 0;
  ApiException? failNextWith;

  /// When set, saves wait for it (an autosave still in flight).
  Completer<void>? saveGate;

  static final criteriaJson = [
    {'id': 'cr100', 'name': 'Interview', 'is_scored': false, 'weight': '0', 'min_points': 0, 'max_points': 0, 'parent_id': null},
    {'id': 'cr101', 'name': 'Communication', 'is_scored': true, 'weight': '10.00', 'min_points': 1, 'max_points': 10, 'parent_id': 'cr100'},
    {'id': 'cr102', 'name': 'Confidence', 'is_scored': true, 'weight': '10.00', 'min_points': 1, 'max_points': 10, 'parent_id': 'cr100'},
    {'id': 'cr103', 'name': 'Substance', 'is_scored': true, 'weight': '10.00', 'min_points': 1, 'max_points': 10, 'parent_id': 'cr100'},
    {'id': 'cr104', 'name': 'Evening Gown', 'is_scored': true, 'weight': '30.00', 'min_points': 1, 'max_points': 10, 'parent_id': null},
    {'id': 'cr105', 'name': 'Stage Presence', 'is_scored': true, 'weight': '40.00', 'min_points': 1, 'max_points': 10, 'parent_id': null, 'step': '0.25'},
  ];

  static final contestantsJson = [
    for (final (id, no, name) in [('rc11', 1, 'Mrs Shaida'), ('rc12', 2, 'Miss Yuka'), ('rc13', 3, 'Mister Jerome')])
      {
        'id': id,
        'round_id': roundId,
        'id_finalis': 'f$id',
        'status': 'active',
        'finalis': {
          'id_finalis': 'f$id', 'nama_finalis': name, 'nomor_urut': no, 'profesi': 'Model', 'poster_finalis': null,
          'nama_tambahan': no == 2 ? 'Yuka Tanaka' : null,
          'usia': no == 2 ? 24 : null,
          // A long biography: the Scoring panel must clamp it (Read more).
          'deskripsi': no == 2 ? List.filled(12, 'Runway model and pageant finalist from Osaka.').join(' ') : null,
        },
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
  Future<Round> round(String roundId) async => Round.fromJson(_roundJson..remove('vote'));

  @override
  Future<List<Contestant>> contestants(String roundId) async => contestantsJson.map(Contestant.fromJson).toList();

  @override
  Future<List<Criterion>> criteria(String roundId) async => criteriaJson.map(Criterion.fromJson).toList();

  @override
  Future<List<ScoreSheetRow>> scoreSheet(String roundId) async => [
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
  Future<void> saveScores(String roundId, List<ScoreInput> scores) async {
    await saveGate?.future;
    _maybeFail();
    // Live (2026-10-09): an empty raw_score is always rejected.
    for (final (i, s) in scores.indexed) {
      if (s.rawScore == null) {
        throw ApiException('The scores.$i.raw_score field is required.',
            statusCode: 422, fieldErrors: {'scores.$i.raw_score': ['The scores.$i.raw_score field is required.']});
      }
    }
    saved.add(scores);
    for (final s in scores) {
      sheet[s.contestantId]![s.criterionId] = s.rawScore;
      comments[s.contestantId] = s.comment;
    }
  }

  @override
  Future<List<ScoreSheetRow>> review(String roundId) => scoreSheet(roundId);

  @override
  Future<void> submit(String roundId, String idempotencyKey) async {
    submitKeys.add(idempotencyKey);
    _maybeFail();
    sheetStatus = 'submitted';
  }

  @override
  Future<ResultSnapshot> results(String roundId) async {
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
