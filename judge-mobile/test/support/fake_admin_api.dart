import 'package:kreen_judge_mobile/admin/admin_models.dart';
import 'package:kreen_judge_mobile/api/admin_api.dart';
import 'package:kreen_judge_mobile/api/api_client.dart';

/// In-memory Admin API built from the captured live responses
/// (event 6ab4883245205: TOP 10 finalized → TOP 5 open, 11 finalists) plus an
/// event without rounds. Ids are strings, as live since 2026-10-09: the
/// captured ones keep their digits ('59', '281'…); ids created here are
/// non-numeric ('x500'…), like the server's hashes.
class FakeAdminApi implements AdminApi {
  static const eventId = '6ab4883245205';
  static const emptyEventId = '6ab4c41520823';

  static Map<String, dynamic> roundJson(
    String id,
    String name,
    int order,
    String status, {
    int topN = 5,
    int criteria = 4,
    int contestants = 9,
    int judges = 1,
    bool favorit = false,
  }) => {
    'id': id,
    'id_vote': eventId,
    'name': name,
    'order_no': order,
    'status': status,
    'promote_mode': 'auto_top_n',
    'promote_top_n': topN,
    'favorit_promote_enabled': favorit,
    'result_visibility': false,
    'opened_at': '2026-09-25T07:25:51.000000Z',
    'closed_at': null,
    'finalized_at': null,
    'created_at': '2026-09-25T07:10:55.000000Z',
    'updated_at': '2026-09-25T07:43:17.000000Z',
    'tie_acknowledged_at': null,
    'tie_acknowledged_by': null,
    'criteria_count': criteria,
    'contestants_count': contestants,
    'judges_count': judges,
  };

  final List<Map<String, dynamic>> roundRows = [
    roundJson('59', 'TOP 10', 1, 'finalized', favorit: true),
    roundJson('60', 'TOP 5', 2, 'open', topN: 3, contestants: 5),
  ];

  static Map<String, dynamic> eventJson(String id, String title, {bool active = true, Object? rounds}) => {
    'id_vote': id,
    'judul_vote': title,
    'slug': title.toLowerCase().replaceAll(' ', '_'),
    'banner': null,
    'flag_aktif': active,
    'tanggal_buka_vote': '2026-09-24 10:06:00',
    'tanggal_tutup_vote': '2026-09-30 09:21:00',
    'tanggal_grandfinal_mulai': '2026-10-02',
    'rounds': rounds ?? {'total': 0, 'draft': 0, 'open': 0, 'closed': 0, 'finalized': 0},
  };

  static final contestantsJson = [
    for (var i = 1; i <= 11; i++)
      {
        'id_finalis': 'f$i',
        'id_vote': eventId,
        'nama_finalis': 'Finalis $i',
        'nama_tambahan': i == 11 ? null : 'Nama Tambahan $i',
        'profesi': i == 11 ? null : 'Profesi / Aktivitas $i',
        'nomor_urut': i,
        'usia': i == 11 ? null : 24 + i,
        'poster_finalis': null,
        'total_voters': 0,
      },
  ];

  final List<({int page, String? search})> eventQueries = [];
  final List<Map<String, Object?>> created = [];
  ApiException? failNext;

  void _maybeFail() {
    final e = failNext;
    failNext = null;
    if (e != null) throw e;
  }

  @override
  Future<AdminEventPage> events({int page = 1, String? search}) async {
    eventQueries.add((page: page, search: search));
    _maybeFail();
    final all = [
      eventJson(
        eventId,
        'Testing Laravel 13 Final',
        rounds: {'total': 2, 'draft': 0, 'open': 1, 'closed': 0, 'finalized': 1},
      ),
      eventJson(emptyEventId, 'testing free', active: false),
    ].where((e) => search == null || '${e['judul_vote']}'.toLowerCase().contains(search.toLowerCase()));
    return AdminEventPage(items: [for (final e in all) AdminEvent.fromApi(e)], total: all.length);
  }

  @override
  Future<AdminEventDetail> event(String idVote) async {
    _maybeFail();
    final json = idVote == eventId
        ? {...eventJson(eventId, 'Testing Laravel 13 Final', rounds: roundRows), 'total_finalis': 11, 'settings': null}
        : {...eventJson(emptyEventId, 'testing free', rounds: <Object>[]), 'total_finalis': 0, 'settings': null};
    return AdminEventDetail(
      event: AdminEvent.fromApi(json),
      rounds: [for (final r in json['rounds'] as List) AdminRound.fromApi(r as Map<String, dynamic>)],
    );
  }

  @override
  Future<List<AdminRound>> rounds(String idVote) async => [for (final r in roundRows) AdminRound.fromApi(r)];

  // ------------------------------------------------------------ rounds

  /// round id → round contestants (`id` = round_contestant id → `f<n>`).
  final Map<String, List<(String, String)>> roundContestantRows = {
    '59': [for (var i = 1; i <= 9; i++) ('${49 + i}', 'f$i')],
    '60': [('59', 'f1'), ('61', 'f5'), ('60', 'f3'), ('62', 'f6'), ('63', 'f7')],
  };
  final Map<String, List<(String, bool)>> roundJudgeRows = {
    '59': [('281', true)],
    '60': [('281', true)],
  };
  final Map<String, List<Map<String, dynamic>>> criteriaRows = {
    for (final r in ['59', '60'])
      r: [
        for (final (i, (name, w)) in [
          ('Kerapian', 10),
          ('Inisiatif', 20),
          ('Moralitas', 30),
          ('Kesigapan', 40),
        ].indexed)
          {
            'id': '${(r == '59' ? 53 : 57) + i}',
            'round_id': r,
            'name': name,
            'description': '$name Peserta',
            'min_points': 0,
            'max_points': 100,
            'weight': '$w.00',
            'is_scored': true,
            'parent_id': null,
            'flag_aktif': true,
            'step': null,
          },
      ],
  };

  /// round id → judge id → sheet statuses by round_contestant id.
  final Map<String, Map<String, Map<String, String>>> sheets = {
    '59': {
      '281': {for (var i = 50; i <= 58; i++) '$i': 'submitted'},
    },
    '60': {
      '281': {'59': 'in_progress'},
    },
  };
  static const _scores59 = {
    '50': 79.4,
    '54': 79.1,
    '52': 75.9,
    '55': 68.1,
    '56': 67.7,
    '58': 62.6,
    '53': 55.8,
    '51': 53.0,
    '57': 51.8,
  };
  final List<String> roundCalls = [];

  /// Every round GET, as "what roundId" (to check what a tab/action loads).
  final List<String> gets = [];
  int _nextId = 500;

  /// A new id, non-numeric like the live hashes.
  String _newId() => 'x${_nextId++}';

  Map<String, dynamic> _row(String id) => roundRows.firstWhere((r) => r['id'] == id);
  Map<String, dynamic> _finalis(String ext) => contestantsJson.firstWhere((c) => c['id_finalis'] == ext);

  @override
  Future<AdminRound> round(String id) async {
    gets.add('round $id');
    final r = _row(id);
    r['contestants_count'] = roundContestantRows[id]?.length ?? 0;
    r['judges_count'] = roundJudgeRows[id]?.length ?? 0;
    r['criteria_count'] = criteriaRows[id]?.length ?? 0;
    return AdminRound.fromApi(r);
  }

  @override
  Future<void> updateRound(
    String id, {
    required String name,
    required String promoteMode,
    required int promoteTopN,
    required bool favoritPromoteEnabled,
  }) async {
    _maybeFail();
    roundCalls.add('update $id $name');
    _row(id)
      ..['name'] = name
      ..['promote_mode'] = promoteMode
      ..['promote_top_n'] = promoteTopN
      ..['favorit_promote_enabled'] = favoritPromoteEnabled;
  }

  @override
  Future<void> deleteRound(String id) async {
    _maybeFail();
    roundCalls.add('delete $id');
    roundRows.removeWhere((r) => r['id'] == id);
  }

  void _status(String id, String status) {
    _maybeFail();
    roundCalls.add('$status $id');
    _row(id)['status'] = status;
  }

  @override
  Future<void> openRound(String id) async => _status(id, 'open');
  @override
  Future<void> closeRound(String id) async => _status(id, 'closed');
  @override
  Future<void> finalizeRound(String id) async => _status(id, 'finalized');

  @override
  Future<List<Map<String, dynamic>>> roundContestants(String id) async {
    gets.add('contestants $id');
    return [
      for (final (rc, ext) in roundContestantRows[id] ?? const <(String, String)>[])
        {
          'id': rc,
          'round_id': id,
          'id_finalis': ext,
          'entry_type': 'manual',
          'status': 'active',
          'finalis': _finalis(ext),
        },
    ];
  }

  @override
  Future<void> addRoundContestant(String id, String idFinalis, {String entryType = 'manual'}) async {
    _maybeFail();
    roundCalls.add('add contestant $id $idFinalis');
    roundContestantRows.putIfAbsent(id, () => []).add((_newId(), idFinalis));
  }

  @override
  Future<void> removeRoundContestant(String id, String roundContestantId) async {
    _maybeFail();
    roundCalls.add('remove contestant $id $roundContestantId');
    roundContestantRows[id]?.removeWhere((e) => e.$1 == roundContestantId);
  }

  @override
  Future<List<Map<String, dynamic>>> roundJudges(String id) async {
    gets.add('judges $id');
    return [
      for (final (judgeId, required) in roundJudgeRows[id] ?? const <(String, bool)>[])
        // Live (2026-10-08): only assigned, active judges are listed.
        if (!(excusedJudges[id]?.contains(judgeId) ?? false))
          {
            'id': 'a$judgeId',
            'round_id': id,
            'judge_id': judgeId,
            'required': required,
            'assignment_status': 'assigned',
            'excuse_reason': null,
            'flag_aktif': true,
            'judge': judgeRows.firstWhere((j) => j['id'] == judgeId),
          },
    ];
  }

  /// `round:roundContestant` of the sheets reopened (they carry `reopened_at`).
  final Set<String> reopenedSheets = {};

  /// round id → excused judge ids (left out of GET rounds/{id}/judges).
  final Map<String, Set<String>> excusedJudges = {};

  @override
  Future<void> updateRoundJudge(
    String id,
    String judgeId, {
    bool? required,
    String? status,
    String? excuseReason,
  }) async {
    _maybeFail();
    roundCalls.add(
      'update judge $id $judgeId'
      '${required == null ? '' : ' required=$required'}${status == null ? '' : ' $status'}'
      '${excuseReason == null ? '' : ' ($excuseReason)'}',
    );
    final rows = roundJudgeRows[id]!;
    final i = rows.indexWhere((e) => e.$1 == judgeId);
    if (required != null) rows[i] = (judgeId, ignoreRequired || required);
    if (status == 'excused') excusedJudges.putIfAbsent(id, () => {}).add(judgeId);
    if (status == 'assigned') excusedJudges[id]?.remove(judgeId);
  }

  /// Simulates a server that ignores `required` on assign.
  bool ignoreRequired = false;

  @override
  Future<void> addRoundJudge(String id, String judgeId, {bool required = true}) async {
    _maybeFail();
    roundCalls.add('add judge $id $judgeId${required ? '' : ' optional'}');
    roundJudgeRows.putIfAbsent(id, () => []).add((judgeId, ignoreRequired || required));
  }

  @override
  Future<void> removeRoundJudge(String id, String judgeId) async {
    _maybeFail();
    roundCalls.add('remove judge $id $judgeId');
    roundJudgeRows[id]?.removeWhere((e) => e.$1 == judgeId);
  }

  @override
  Future<List<Map<String, dynamic>>> criteria(String id) async {
    gets.add('criteria $id');
    return [...?criteriaRows[id]];
  }

  /// Every criterion body sent (create / update), in order.
  final List<Map<String, dynamic>> criterionBodies = [];

  @override
  Future<String?> createCriterion(String id, Map<String, dynamic> body) async {
    _maybeFail();
    criterionBodies.add(body);
    roundCalls.add('create criterion $id ${body['name']} ${body['weight']}');
    final newId = _newId();
    criteriaRows.putIfAbsent(id, () => []).add({
      'is_scored': true,
      'parent_id': null,
      'step': null,
      ...body,
      'id': newId,
      'round_id': id,
      'flag_aktif': true,
    });
    return newId;
  }

  @override
  Future<void> updateCriterion(String id, String criterionId, Map<String, dynamic> body) async {
    _maybeFail();
    criterionBodies.add({...body, 'id': criterionId});
    roundCalls.add('update criterion $id $criterionId ${body['weight']}');
    criteriaRows[id]!.firstWhere((c) => c['id'] == criterionId).addAll(body);
  }

  @override
  Future<void> deleteCriterion(String id, String criterionId) async {
    _maybeFail();
    roundCalls.add('delete criterion $id $criterionId');
    criteriaRows[id]!.removeWhere((c) => c['id'] == criterionId);
  }

  @override
  Future<Map<String, dynamic>> monitoring(String id) async {
    gets.add('monitoring $id');
    final total = roundContestantRows[id]?.length ?? 0;
    return {
      'round_status': _row(id)['status'],
      'total_contestants': total,
      'judges': [
        for (final (judgeId, _) in roundJudgeRows[id] ?? const <(String, bool)>[])
          () {
            final own = sheets[id]?[judgeId] ?? const <String, String>{};
            final submitted = own.values.where((s) => s == 'submitted').length;
            return {
              'judge_id': judgeId,
              'judge_name': judgeRows.firstWhere((j) => j['id'] == judgeId)['name'],
              'assignment_active': true,
              'total_contestants': total,
              'submitted': submitted,
              'in_progress': own.length - submitted,
              'is_done': total > 0 && submitted == total,
              'sheets': [
                for (final e in own.entries)
                  {
                    'score_sheet_id': 's$id:${e.key}',
                    'round_contestant_id': e.key,
                    'status': e.value,
                    'reopened_at': reopenedSheets.contains('$id:${e.key}') ? '2026-10-09 10:00:00' : null,
                    'submitted_at': e.value == 'submitted' ? '2026-09-25T07:38:13.000000Z' : null,
                  },
              ],
            };
          }(),
      ],
    };
  }

  @override
  Future<void> reopenScoreSheet(String id, String scoreSheetId, String reason) async {
    _maybeFail();
    roundCalls.add('reopen $id $scoreSheetId $reason');
    // Live (2026-10-09): back to `in_progress`, marked with `reopened_at`.
    final rc = scoreSheetId.split(':').last;
    for (final own in sheets[id]!.values) {
      if (own.containsKey(rc)) own[rc] = 'in_progress';
    }
    reopenedSheets.add('$id:$rc');
  }

  @override
  Future<Map<String, dynamic>?> results(String id) async {
    gets.add('results $id');
    final status = _row(id)['status'];
    if (status != 'open' && status != 'closed' && status != 'finalized') return null;
    final rows = roundContestantRows[id]!;
    final scored = [
      for (final (rc, ext) in rows) (rc, ext, _scores59[rc] ?? 60.0 - rc.codeUnits.fold<int>(0, (a, b) => a + b) % 7),
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    return {
      'id': 'res$id',
      'round_id': id,
      'computed_at': '2026-09-25T07:43:17.000000Z',
      'is_final': status == 'finalized',
      // Open: a preview from submitted sheets — every contestant listed even
      // before anyone submits (as the server does since 2026-10-16).
      if (status == 'open') 'is_preview': true,
      'items': [
        for (final (i, (rc, ext, score)) in scored.indexed)
          {
            'round_contestant_id': rc,
            'avg_score': score,
            'rank_no': i + 1,
            'contestant': {'id': rc, 'round_id': id, 'id_finalis': ext, 'status': 'active', 'finalis': _finalis(ext)},
          },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> resultDetail(String id, String roundContestantId) async => {
    'summary': {'round_contestant_id': roundContestantId, 'avg_score': _scores59[roundContestantId] ?? 0},
    'per_juri': [
      {
        'judge_id': '281',
        'round_contestant_id': roundContestantId,
        'status': 'submitted',
        'judge': judgeRows.first,
        'scores': [
          for (final c in criteriaRows[id]!)
            {'round_criteria_id': c['id'], 'raw_score': 80, 'total_score': 80 * double.parse('${c['weight']}') / 100},
        ],
      },
    ],
  };

  @override
  Future<void> setResultVisibility(String id, bool visible) async {
    _maybeFail();
    roundCalls.add('visibility $id $visible');
    _row(id)['result_visibility'] = visible;
  }

  @override
  Future<Map<String, dynamic>> advancement(String id) async {
    gets.add('advancement $id');
    final next = roundRows.where((r) => (r['order_no'] as int) == (_row(id)['order_no'] as int) + 1).firstOrNull;
    final ranked = (await results(id))?['items'] as List? ?? const [];
    final topN = _row(id)['promote_top_n'] as int;
    return {
      'source': {'id': id},
      'target': next == null ? null : {'id': next['id'], 'status': next['status']},
      'can_confirm': next != null && next['status'] == 'draft',
      'blocking_reason': next != null && next['status'] != 'draft'
          ? 'Ronde ${next['name']} sudah open; advancement cuma bisa ke ronde draft.'
          : null,
      'suggested_contestant_ids': [for (final i in ranked.take(topN)) (i as Map)['round_contestant_id']],
      'cutoff_tie': false,
      'favorit_candidate': null,
      'history': [
        if (advanced[id] != null)
          {'type': 'confirmed', 'method': 'manual', 'reason': '', 'actor': 'a', 'at': '2026-09-30T09:00:00Z'},
      ],
      // Live shape: the *target* round's promoted contestants (own ids + finalis).
      'current': next == null
          ? <Object>[]
          : [
              for (final (rc, ext) in roundContestantRows[next['id'] as String] ?? const <(String, String)>[])
                if (advanced[id] != null)
                  {
                    'id': rc,
                    'round_id': next['id'],
                    'id_finalis': ext,
                    'entry_type': 'promoted',
                    'finalis': _finalis(ext),
                  },
            ],
    };
  }

  /// source round id → confirmed round_contestant ids.
  final Map<String, List<String>> advanced = {};

  @override
  Future<void> confirmAdvancement(
    String id, {
    required List<String> roundContestantIds,
    required String reason,
    required bool includeFavorit,
  }) async {
    _maybeFail();
    roundCalls.add('advance $id ${roundContestantIds.join(',')} $reason $includeFavorit');
    advanced[id] = [...roundContestantIds];
    final next = roundRows.firstWhere((r) => (r['order_no'] as int) == (_row(id)['order_no'] as int) + 1);
    final byRc = {for (final (rc, ext) in roundContestantRows[id]!) rc: ext};
    roundContestantRows[next['id'] as String] = [for (final rc in roundContestantIds) (_newId(), byRc[rc]!)];
  }

  @override
  Future<void> resetAdvancement(String id, String reason) async {
    _maybeFail();
    roundCalls.add('reset advancement $id $reason');
    advanced.remove(id);
    final next = roundRows.firstWhere((r) => (r['order_no'] as int) == (_row(id)['order_no'] as int) + 1);
    roundContestantRows[next['id'] as String] = [];
  }

  ServerEventSettings settings = const ServerEventSettings(voteIdTheme: 0);

  @override
  Future<ServerEventSettings> eventSettings(String idVote) async => settings;

  @override
  Future<void> updateEventSettings(String idVote, ServerEventSettings value) async {
    _maybeFail();
    settings = value;
  }

  @override
  Future<List<Map<String, dynamic>>> themes() async => [
    {'id': 0, 'name': 'default', 'primary': '235,46,46', 'icon': '235,46,46'},
    {'id': 1, 'name': 'Blue', 'primary': '41,69,143', 'icon': '150, 179, 255'},
    {'id': 3, 'name': 'Green', 'primary': '0,143,95', 'icon': '134, 229, 198'},
  ];

  @override
  Future<AdminRound> createRound(
    String idVote, {
    required String name,
    required String promoteMode,
    required int promoteTopN,
    required bool favoritPromoteEnabled,
  }) async {
    _maybeFail();
    created.add({
      'name': name,
      'promote_mode': promoteMode,
      'promote_top_n': promoteTopN,
      'favorit': favoritPromoteEnabled,
    });
    final json = roundJson(
      _newId(),
      name,
      roundRows.length + 1,
      'draft',
      topN: promoteTopN,
      criteria: 0,
      contestants: 0,
      judges: 0,
    );
    roundRows.add(json);
    return AdminRound.fromApi(json);
  }

  @override
  Future<List<Map<String, dynamic>>> contestants(String idVote, {String? search}) async =>
      idVote == eventId ? contestantsJson : const [];

  /// Captured `GET /judge/admin/judges` items.
  final List<Map<String, dynamic>> judgeRows = [
    {
      'id': '281',
      'id_merchant': 'm',
      'name': 'Admin Juri Free',
      'created_at': '2026-09-24T07:33:15.000000Z',
      'email': 'admin.free@test.com',
      'phone': '081300000001',
      'flag_aktif': 1,
      'capabilities': [
        {'id': '22', 'judge_id': '281', 'capability': 'super_admin', 'scope_type': 'global', 'scope_id': null},
      ],
    },
    {
      'id': '283',
      'created_at': '2026-09-24T07:33:17.000000Z',
      'id_merchant': 'm',
      'name': 'Juri Free Dua',
      'email': 'juri2.free@test.com',
      'phone': '081300000003',
      'flag_aktif': 1,
      'capabilities': [],
    },
    {
      'id': '282',
      'created_at': '2026-09-24T07:33:16.000000Z',
      'id_merchant': 'm',
      'name': 'Juri Free Satu',
      'email': 'juri1.free@test.com',
      'phone': '081300000002',
      'flag_aktif': 1,
      'capabilities': [],
    },
  ];
  final List<String> judgeCalls = [];

  @override
  Future<List<Map<String, dynamic>>> judges() async => [...judgeRows];

  @override
  Future<void> createJudge({
    required String name,
    required String email,
    required String password,
    required String phone,
    required bool active,
  }) async {
    _maybeFail();
    judgeCalls.add('create $email $password');
    judgeRows.add({
      'id': _newId(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'name': name,
      'email': email,
      'phone': phone,
      'flag_aktif': active ? 1 : 0,
      'capabilities': [],
    });
  }

  @override
  Future<void> updateJudge(
    String id, {
    required String name,
    required String email,
    String? password,
    required String phone,
    required bool active,
  }) async {
    _maybeFail();
    judgeCalls.add('update $id ${password ?? ''}');
    final row = judgeRows.firstWhere((j) => j['id'] == id);
    row
      ..['name'] = name
      ..['email'] = email
      ..['phone'] = phone
      ..['flag_aktif'] = active ? 1 : 0;
  }

  @override
  Future<void> deleteJudge(String id) async {
    _maybeFail();
    judgeCalls.add('delete $id');
    judgeRows.removeWhere((j) => j['id'] == id);
  }

  @override
  Future<void> setJudgeRoles(String id, List<(String, String?)> roles) async {
    judgeCalls.add('roles $id ${roles.map((r) => r.$1).join(',')}');
    judgeRows.firstWhere((j) => j['id'] == id)['capabilities'] = [
      for (final (role, scope) in roles) {'capability': role, 'scope_id': scope},
    ];
  }
}
