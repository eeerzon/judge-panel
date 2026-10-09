// Admin endpoints (`/api/v1/judge/admin/...`). Only what the backend exposes
// today: events (dashboard + detail), rounds (list + create), the contestant
// master (read — create/update/delete answer "Belum tersedia") and the judge
// master (CRUD + roles). Everything else in Admin Mode is still prototype
// data (see AdminStore).

import '../admin/admin_models.dart';
import 'api_client.dart';

abstract class AdminApi {
  Future<AdminEventPage> events({int page = 1, String? search});
  Future<AdminEventDetail> event(String idVote);
  Future<List<AdminRound>> rounds(String idVote);
  Future<AdminRound> createRound(
    String idVote, {
    required String name,
    required String promoteMode,
    required int promoteTopN,
    required bool favoritPromoteEnabled,
  });
  Future<List<Map<String, dynamic>>> contestants(String idVote, {String? search});

  /// Raw judge master items, all pages of `GET /judge/admin/judges`.
  Future<List<Map<String, dynamic>>> judges();
  Future<void> createJudge({required String name, required String email, required String password, required String phone, required bool active});

  /// [password] null/empty = unchanged.
  Future<void> updateJudge(int id, {required String name, required String email, String? password, required String phone, required bool active});
  Future<void> deleteJudge(int id);

  /// `PUT /judge/admin/judges/{id}/roles` — [roles] as `(role, scopeId)`.
  Future<void> setJudgeRoles(int id, List<(String, String?)> roles);

  // ------------------------------------------------ rounds (`/judge/admin/rounds/{id}`)
  Future<AdminRound> round(int id);
  Future<void> updateRound(int id,
      {required String name, required String promoteMode, required int promoteTopN, required bool favoritPromoteEnabled});
  Future<void> deleteRound(int id);
  Future<void> openRound(int id);
  Future<void> closeRound(int id);
  Future<void> finalizeRound(int id);

  /// Round contestants (`id` = round_contestant id, with `finalis`).
  Future<List<Map<String, dynamic>>> roundContestants(int id);
  Future<void> addRoundContestant(int id, String idFinalis, {String entryType = 'manual'});
  Future<void> removeRoundContestant(int id, int roundContestantId);

  /// Round judge assignments (with `judge`).
  Future<List<Map<String, dynamic>>> roundJudges(int id);
  /// [required] false = Optional judge (does not block Close Round).
  Future<void> addRoundJudge(int id, int judgeId, {bool required = true});
  Future<void> removeRoundJudge(int id, int judgeId);

  /// `PATCH rounds/{id}/judges/{judgeId}` ({judgeId} = judge_id) — updates the
  /// existing assignment; only the given fields are sent. [status]:
  /// assigned | excused | removed ([excuseReason] required for excused).
  Future<void> updateRoundJudge(int id, int judgeId, {bool? required, String? status, String? excuseReason});

  Future<List<Map<String, dynamic>>> criteria(int id);
  /// Returns the created criterion's id (null if the response has none).
  Future<int?> createCriterion(int id, Map<String, dynamic> body);
  Future<void> updateCriterion(int id, int criterionId, Map<String, dynamic> body);
  Future<void> deleteCriterion(int id, int criterionId);

  Future<Map<String, dynamic>> monitoring(int id);
  Future<void> reopenScoreSheet(int id, int scoreSheetId, String reason);

  /// Null until the round has a result (e.g. while open).
  Future<Map<String, dynamic>?> results(int id);
  Future<Map<String, dynamic>> resultDetail(int id, int roundContestantId);
  Future<void> setResultVisibility(int id, bool visible);
  Future<Map<String, dynamic>> advancement(int id);
  Future<void> confirmAdvancement(int id, {required List<int> roundContestantIds, required String reason, required bool includeFavorit});

  /// [reason] 3–1000 characters.
  Future<void> resetAdvancement(int id, String reason);

  // ------------------------------------------------ event settings
  Future<ServerEventSettings> eventSettings(String idVote);

  /// `GET /create-vote/themes` (`data.themes[]`), raw.
  Future<List<Map<String, dynamic>>> themes();
  Future<void> updateEventSettings(String idVote, ServerEventSettings settings);
}

class HttpAdminApi implements AdminApi {
  HttpAdminApi(this.client);
  final ApiClient client;

  static List<Map<String, dynamic>> _list(dynamic data) => [
        if (data is List)
          for (final e in data)
            if (e is Map) Map<String, dynamic>.from(e),
      ];

  static Map<String, dynamic> _map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};

  static String _query(Map<String, Object?> params) {
    final q = {
      for (final e in params.entries)
        if (e.value != null && '${e.value}'.trim().isNotEmpty) e.key: '${e.value}'.trim(),
    };
    return q.isEmpty ? '' : '?${Uri(queryParameters: q).query}';
  }

  @override
  Future<AdminEventPage> events({int page = 1, String? search}) async {
    final body = await client.getEnvelope('/judge/admin/dashboard${_query({'page': page, 'search': search})}');
    final meta = _map(body['meta']);
    int n(Object? v, int f) => v is num ? v.toInt() : int.tryParse('$v') ?? f;
    return AdminEventPage(
      items: [for (final e in _list(body['data'])) AdminEvent.fromApi(e)],
      currentPage: n(meta['current_page'], page),
      lastPage: n(meta['last_page'], page),
      total: n(meta['total'], 0),
    );
  }

  @override
  Future<AdminEventDetail> event(String idVote) async {
    final data = _map(await client.get('/judge/admin/events/${Uri.encodeComponent(idVote)}'));
    return AdminEventDetail(
      event: AdminEvent.fromApi(data),
      rounds: [for (final r in _list(data['rounds'])) AdminRound.fromApi(r)],
    );
  }

  @override
  Future<List<AdminRound>> rounds(String idVote) async =>
      [for (final r in _list(await client.get('/judge/admin/events/${Uri.encodeComponent(idVote)}/rounds'))) AdminRound.fromApi(r)];

  @override
  Future<AdminRound> createRound(
    String idVote, {
    required String name,
    required String promoteMode,
    required int promoteTopN,
    required bool favoritPromoteEnabled,
  }) async =>
      AdminRound.fromApi(_map(await client.post('/judge/admin/events/${Uri.encodeComponent(idVote)}/rounds', {
        'name': name,
        'promote_mode': promoteMode,
        'promote_top_n': promoteTopN,
        'favorit_promote_enabled': favoritPromoteEnabled,
      })));

  @override
  Future<List<Map<String, dynamic>>> judges() async {
    final items = <Map<String, dynamic>>[];
    for (var page = 1, last = 1; page <= last && page <= 50; page++) {
      final body = await client.getEnvelope('/judge/admin/judges${_query({'page': page})}');
      items.addAll(_list(body['data']));
      final l = _map(body['meta'])['last_page'];
      last = l is num ? l.toInt() : int.tryParse('$l') ?? page;
    }
    return items;
  }

  static Map<String, dynamic> _judgeBody(String name, String email, String? password, String phone, bool active) => {
        'name': name.trim(),
        'email': email.trim(),
        if (password != null && password.isNotEmpty) 'password': password,
        'phone': phone.trim(),
        'flag_aktif': active,
      };

  @override
  Future<void> createJudge({required String name, required String email, required String password, required String phone, required bool active}) =>
      client.post('/judge/admin/judges', _judgeBody(name, email, password, phone, active));

  @override
  Future<void> updateJudge(int id, {required String name, required String email, String? password, required String phone, required bool active}) =>
      client.patch('/judge/admin/judges/$id', _judgeBody(name, email, password, phone, active));

  @override
  Future<void> deleteJudge(int id) => client.delete('/judge/admin/judges/$id');

  @override
  Future<void> setJudgeRoles(int id, List<(String, String?)> roles) => client.put('/judge/admin/judges/$id/roles', {
        'roles': [for (final (role, scope) in roles) {'role': role, 'scope_id': scope}],
      });

  static String _r(int id) => '/judge/admin/rounds/$id';

  @override
  Future<AdminRound> round(int id) async => AdminRound.fromApi(_map(await client.get(_r(id))));

  @override
  Future<void> updateRound(int id,
          {required String name, required String promoteMode, required int promoteTopN, required bool favoritPromoteEnabled}) =>
      client.patch(_r(id), {
        'name': name.trim(),
        'promote_mode': promoteMode,
        'promote_top_n': promoteTopN,
        'favorit_promote_enabled': favoritPromoteEnabled,
      });

  @override
  Future<void> deleteRound(int id) => client.delete(_r(id));

  @override
  Future<void> openRound(int id) => client.post('${_r(id)}/open');

  @override
  Future<void> closeRound(int id) => client.post('${_r(id)}/close');

  @override
  Future<void> finalizeRound(int id) => client.post('${_r(id)}/finalize');

  @override
  Future<List<Map<String, dynamic>>> roundContestants(int id) async => _list(await client.get('${_r(id)}/contestants'));

  @override
  Future<void> addRoundContestant(int id, String idFinalis, {String entryType = 'manual'}) =>
      client.post('${_r(id)}/contestants', {'id_finalis': idFinalis, 'entry_type': entryType});

  @override
  Future<void> removeRoundContestant(int id, int roundContestantId) =>
      client.delete('${_r(id)}/contestants/$roundContestantId');

  @override
  Future<List<Map<String, dynamic>>> roundJudges(int id) async => _list(await client.get('${_r(id)}/judges'));

  @override
  Future<void> addRoundJudge(int id, int judgeId, {bool required = true}) =>
      client.post('${_r(id)}/judges', {'judge_id': judgeId, 'required': required});

  @override
  Future<void> removeRoundJudge(int id, int judgeId) => client.delete('${_r(id)}/judges/$judgeId');

  @override
  Future<void> updateRoundJudge(int id, int judgeId, {bool? required, String? status, String? excuseReason}) =>
      client.patch('${_r(id)}/judges/$judgeId', {
        'required': ?required,
        'assignment_status': ?status,
        'excuse_reason': ?excuseReason,
      });

  /// The server nests sub-criteria in `children` (top level in `data`);
  /// the store works on a flat list (parent first, then its children, each
  /// with `parent_id`). A flat response is read as it is.
  static List<Map<String, dynamic>> flattenCriteria(Object? data, [Object? parentId]) {
    final out = <Map<String, dynamic>>[];
    for (final c in _list(data)) {
      final children = c.remove('children'); // _list copies, the response is untouched
      out.add({...c, if (c['parent_id'] == null && parentId != null) 'parent_id': parentId});
      out.addAll(flattenCriteria(children, c['id']));
    }
    return out;
  }

  @override
  Future<List<Map<String, dynamic>>> criteria(int id) async => flattenCriteria(await client.get('${_r(id)}/criteria'));

  @override
  Future<int?> createCriterion(int id, Map<String, dynamic> body) async {
    final created = _map(await client.post('${_r(id)}/criteria', body))['id'];
    return created is num ? created.toInt() : int.tryParse('$created');
  }

  @override
  Future<void> updateCriterion(int id, int criterionId, Map<String, dynamic> body) =>
      client.patch('${_r(id)}/criteria/$criterionId', body);

  @override
  Future<void> deleteCriterion(int id, int criterionId) => client.delete('${_r(id)}/criteria/$criterionId');

  @override
  Future<Map<String, dynamic>> monitoring(int id) async => _map(await client.get('${_r(id)}/monitoring'));

  @override
  Future<void> reopenScoreSheet(int id, int scoreSheetId, String reason) =>
      client.post('${_r(id)}/score-sheets/$scoreSheetId/reopen', {'reason': reason});

  @override
  Future<Map<String, dynamic>?> results(int id) async {
    final data = await client.get('${_r(id)}/results');
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  @override
  Future<Map<String, dynamic>> resultDetail(int id, int roundContestantId) async =>
      _map(await client.get('${_r(id)}/results/$roundContestantId'));

  @override
  Future<void> setResultVisibility(int id, bool visible) =>
      client.patch('${_r(id)}/results/visibility', {'result_visibility': visible});

  @override
  Future<Map<String, dynamic>> advancement(int id) async => _map(await client.get('${_r(id)}/advancement'));

  @override
  Future<void> confirmAdvancement(int id, {required List<int> roundContestantIds, required String reason, required bool includeFavorit}) =>
      client.post('${_r(id)}/advancement', {
        'include_favorit': includeFavorit,
        'reason': reason,
        'round_contestant_ids': roundContestantIds,
      });

  @override
  Future<void> resetAdvancement(int id, String reason) => client.delete('${_r(id)}/advancement${_query({'reason': reason})}');

  @override
  Future<List<Map<String, dynamic>>> themes() async => _list(_map(await client.get('/create-vote/themes'))['themes']);

  @override
  Future<ServerEventSettings> eventSettings(String idVote) async =>
      ServerEventSettings.fromApi(_map(await client.get('/judge/admin/events/${Uri.encodeComponent(idVote)}/settings')));

  @override
  Future<void> updateEventSettings(String idVote, ServerEventSettings settings) =>
      client.patch('/judge/admin/events/${Uri.encodeComponent(idVote)}/settings', settings.toApi());

  /// Raw items: the store maps `id_finalis` to its stable local ids.
  @override
  Future<List<Map<String, dynamic>>> contestants(String idVote, {String? search}) async =>
      _list(await client.get('/judge/admin/contestants${_query({'id_vote': idVote, 'search': search})}'));
}
