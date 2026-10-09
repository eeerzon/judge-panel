import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kreen_judge_mobile/admin/admin_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kreen_judge_mobile/api/admin_api.dart';
import 'package:kreen_judge_mobile/api/api_client.dart';
import 'package:kreen_judge_mobile/api/judge_api.dart';
import 'package:kreen_judge_mobile/domain/models.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';

// Bodies captured from the live API (newvote.kreenconnect.com) on 2026-09-24.
const _login =
    '{"success":true,"message":"Login berhasil.","data":{"access_token":"eyJ.abc.def","token_type":"Bearer","expires_in":3600,"judge":{"id":282,"id_merchant":"234yrejhi832yri3iorj","name":"Juri Free Satu","email":"juri1.free@test.com"}}}';
const _rounds =
    '{"success":true,"data":[{"id":41,"id_vote":"65aa671dea22a","name":"Test Reopen Guard","order_no":1,"status":"closed","promote_mode":"auto_top_n","promote_top_n":null,"favorit_promote_enabled":false,"result_visibility":false,"opened_at":"2026-09-24T07:14:20.000000Z","closed_at":"2026-09-24T07:15:37.000000Z","finalized_at":null,"created_at":"2026-09-24T07:14:12.000000Z","updated_at":"2026-09-24T07:15:37.000000Z","tie_acknowledged_at":null,"tie_acknowledged_by":null,"vote":{"id_vote":"65aa671dea22a","judul_vote":"TESTING"}}]}';
const _contestants =
    '{"success":true,"data":[{"id":35,"round_id":41,"id_finalis":"65aa67343ce98","entry_type":"manual","promoted_from_round_id":null,"status":"active","score_sheet_status":"submitted","finalis":{"id_finalis":"65aa67343ce98","poster_finalis":"https://stagingvote.kreen.id/img_up/up_banner/x.png","nama_finalis":"test","nama_tambahan":"ST","profesi":"Mahasiswa","nomor_urut":4}}]}';
const _criteria =
    '{"success":true,"data":[{"id":38,"round_id":41,"name":"A","description":null,"min_points":0,"max_points":100,"weight":"100.00","is_scored":true,"parent_id":null,"flag_aktif":true,"step":null}]}';
const _sheet =
    '{"success":true,"data":[{"round_contestant_id":35,"id_finalis":"65aa67343ce98","nama_finalis":"test","sheet_status":"submitted","scores":[{"round_criteria_id":38,"criteria_name":"A","max_points":100,"weight":"100.00","raw_score":80,"comment":null}]}]}';

void main() {
  late List<http.Request> requests;
  late bool unauthorized;

  HttpJudgeApi apiWith(Map<String, (int, String)> routes) {
    requests = [];
    unauthorized = false;
    final client = ApiClient(
      baseUrl: 'https://api.test/v1',
      httpClient: MockClient((req) async {
        requests.add(req);
        final hit = routes['${req.method} ${req.url.path}'] ?? (404, '{"message":"Not found"}');
        return http.Response(hit.$2, hit.$1, headers: {'content-type': 'application/json'});
      }),
    )
      ..tokenProvider = (() => 'tkn')
      ..onUnauthorized = () => unauthorized = true;
    return HttpJudgeApi(client);
  }

  test('parses live login / rounds / contestants / criteria / score-sheet', () async {
    final api = apiWith({
      'POST /v1/judge/auth/login': (200, _login),
      'GET /v1/judge/rounds': (200, _rounds),
      'GET /v1/judge/rounds/41/contestants': (200, _contestants),
      'GET /v1/judge/rounds/41/criteria': (200, _criteria),
      'GET /v1/judge/rounds/41/score-sheet': (200, _sheet),
    });

    final login = await api.login('juri1.free@test.com', 'x');
    expect((login.accessToken, login.expiresIn.inSeconds, login.judge.id), ('eyJ.abc.def', 3600, '282'));
    expect(login.actorType, ActorType.judge); // no actor_type → judge

    final round = (await api.rounds()).single;
    expect((round.id, round.name, round.status.name, round.eventName), (41, 'Test Reopen Guard', 'closed', 'TESTING'));

    final c = (await api.contestants(41)).single;
    expect((c.id, c.number, c.name, c.subtitle), (35, 4, 'test', 'Mahasiswa'));
    expect(c.photoUrl, startsWith('https://'));

    final k = (await api.criteria(41)).single;
    expect((k.id, k.min, k.max, k.weight, k.step, k.decimals), (38, 0.0, 100.0, 100.0, 1.0, 0));

    final row = (await api.scoreSheet(41)).single;
    expect((row.contestantId, row.sheetStatus, row.scores[38]), (35, 'submitted', 80.0));
    expect(requests.last.headers['Authorization'], 'Bearer tkn');
  });

  test('maps 401/403/422 bodies to ApiException and reports 401', () async {
    final api = apiWith({
      'GET /v1/judge/rounds': (401, '{"message":"Unauthenticated."}'),
      'GET /v1/judge/rounds/999': (403, '{"message":"Kamu tidak ditugaskan ke ronde ini."}'),
      'POST /v1/judge/rounds/41/score-sheet': (
        422,
        '{"message":"Nilai peserta ini sudah disubmit dan terkunci.","errors":{"round_contestant_id":["Nilai peserta ini sudah disubmit dan terkunci."]}}'
      ),
    });

    await expectLater(api.rounds(), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)));
    expect(unauthorized, isTrue);
    await expectLater(
      api.round(999),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Kamu tidak ditugaskan ke ronde ini.')),
    );
    try {
      await api.saveScores(41, const []);
      fail('expected 422');
    } on ApiException catch (e) {
      expect(e.isValidation, isTrue);
      expect(e.fieldErrors['round_contestant_id'], isNotEmpty);
    }
    expect(jsonDecode(requests.last.body), {'scores': <dynamic>[]});
  });

  test('owner login: string judge id + actor_type owner', () async {
    const owner = '{"success":true,"message":"Login berhasil.","data":{"access_token":"eyJ.o.w","token_type":"Bearer",'
        '"expires_in":3600,"actor_type":"owner","judge":{"id":"89549734435e2d5d38e1","id_merchant":"234yrejhi832yri3iorj",'
        '"name":"Risfi","email":"owner@example.com"},"capabilities":[]}}';
    final login = await apiWith({'POST /v1/judge/auth/login': (200, owner)}).login('owner@example.com', 'x');
    expect((login.judge.id, login.judge.name, login.actorType), ('89549734435e2d5d38e1', 'Risfi', ActorType.owner));
  });

  test('advancement history mixes UTC ISO and zone-less WIB times (live shape)', () {
    AdvancementInfo info(List<Map<String, dynamic>> history) =>
        AdvancementInfo.fromApi({'can_confirm': true, 'history': history}, contestantOf: (_) => null, contestantOfFinalis: (_) => null);
    const confirmed = {'type': 'confirmed', 'method': 'manual', 'reason': 'lolos', 'actor': 'a', 'at': '2026-10-01T01:41:39.000000Z'};
    // Live order: confirm 08:41 WIB after a reset at 08:40 WIB → confirmed.
    final live = info([confirmed, {'type': 'reset', 'reason': 'test reset', 'at': '2026-10-01 08:40:49'}]);
    expect(live.confirmed, isTrue);
    expect((live.lastConfirmed!.method, live.lastConfirmed!.reason), ('manual', 'lolos'));
    expect(live.lastConfirmed!.at!.toUtc(), DateTime.utc(2026, 10, 1, 1, 41, 39));
    // A reset at 09:00 WIB is newer than that confirm (a string sort says otherwise).
    expect(info([confirmed, {'type': 'reset', 'reason': 'x', 'at': '2026-10-01 09:00:00'}]).confirmed, isFalse);
    expect(info([]).confirmed, isFalse);
  });

  test('rounds list carries vote.banner; the detail round keeps it', () {
    final listed = Round.fromJson({
      'id': 122, 'name': 'round', 'status': 'finalized', 'id_vote': 'v1',
      'vote': {'id_vote': 'v1', 'judul_vote': 'Testing Laravel 13', 'banner': 'https://x/up_banner/v1.jpg'},
    });
    expect(listed.eventBanner, 'https://x/up_banner/v1.jpg');
    final detail = Round.fromJson({'id': 122, 'name': 'round', 'status': 'open'});
    expect(detail.eventBanner, isNull);
    expect(detail.withEventName(listed.eventName, listed.eventBanner).eventBanner, 'https://x/up_banner/v1.jpg');
  });

  // GET .../criteria since 2026-10-08: sub-criteria nested in `children`
  // (round 144 on the live server).
  const nestedCriteria = '{"success":true,"data":['
      '{"id":134,"round_id":144,"name":"Penampilan","weight":"10.00","is_scored":true,"parent_id":null,"step":null,"flag_aktif":true,"min_points":1,"max_points":10,"children":[]},'
      '{"id":144,"round_id":144,"name":"parent","weight":"0.00","is_scored":false,"parent_id":null,"step":null,"flag_aktif":true,"min_points":1,"max_points":10,"children":['
      '{"id":151,"round_id":144,"name":"child 1 parent","weight":"20.00","is_scored":true,"parent_id":144,"step":null,"flag_aktif":true,"min_points":1,"max_points":10}]}]}';

  test('admin criteria: nested children come back as a flat list, parent first', () {
    final flat = HttpAdminApi.flattenCriteria((jsonDecode(nestedCriteria) as Map)['data']);
    expect([for (final c in flat) (c['id'], c['parent_id'])], [(134, null), (144, null), (151, 144)]);
    expect(flat.every((c) => !c.containsKey('children')), isTrue);
  });

  test('judge criteria: nested children become a parent section with its sub-criteria', () async {
    final api = apiWith({'GET /v1/judge/rounds/144/criteria': (200, nestedCriteria)});
    final sections = buildSections(await api.criteria(144));
    expect([for (final s in sections) '${s.heading}: ${s.criteria.map((c) => c.label).join(', ')}'], [
      'Penampilan: Penampilan',
      'parent: child 1 parent',
    ]);
  });

  test('expired token (after 1 hour): the 401 ends the session instead of failing every action', () async {
    // Token already expired on arrival (expires_in 0 → renewed a minute early).
    final expiredLogin = _login.replaceFirst('"expires_in":3600', '"expires_in":0');
    final client = ApiClient(
      baseUrl: 'https://api.test/v1',
      httpClient: MockClient((req) async => req.url.path.endsWith('/login')
          ? http.Response(expiredLogin, 200, headers: {'content-type': 'application/json'})
          : req.headers['Authorization'] == null
              ? http.Response('{"message":"Unauthenticated."}', 401, headers: {'content-type': 'application/json'})
              : http.Response('{"success":true,"data":[]}', 200, headers: {'content-type': 'application/json'})),
    );
    final api = HttpJudgeApi(client);
    final session = SessionStore.memory(api);
    client
      ..tokenProvider = (() => session.token)
      ..onUnauthorized = session.handleUnauthorized;
    await session.login('juri1.free@test.com', 'password123');
    expect(session.token, isNull); // expired: no longer sent
    await expectLater(api.rounds(), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)));
    expect(session.hasJudgeSession, isFalse);
    expect(session.expiredMessage, 'Your session has ended. Please sign in again.');
  });

  test('judge results in the server row shape (rank_no, avg_score, contestant.finalis) — not 0', () async {
    // Rows as returned for round 145 on the live server (2026-10-08).
    const body = '{"success":true,"data":{"round_id":145,"aggregation_mode":"per_round","is_final":true,'
        '"computed_at":"2026-10-08T04:31:20.000000Z","items":['
        '{"id":205,"round_contestant_id":175,"avg_score":63.33,"accumulated_score":null,"rank_no":1,"contestant":{"id":175,"finalis":{"nama_finalis":"Finalis 2","nomor_urut":2,"profesi":"Profesi / Aktivitas 2"}}},'
        '{"id":206,"round_contestant_id":174,"avg_score":60,"accumulated_score":null,"rank_no":2,"contestant":{"id":174,"finalis":{"nama_finalis":"Finalis 1","nomor_urut":1,"profesi":"Profesi / Aktivitas 1"}}},'
        '{"id":207,"round_contestant_id":176,"avg_score":60,"accumulated_score":null,"rank_no":3,"contestant":{"id":176,"finalis":{"nama_finalis":"Finalis 3","nomor_urut":3,"profesi":"Profesi / Aktivitas 3"}}}]}}';
    final api = apiWith({'GET /v1/judge/rounds/145/results': (200, body)});
    final result = await api.results(145);
    expect([for (final i in result.items) '${i.rank} ${i.name} ${i.combinedScore} ${i.tied}'], [
      '1 Finalis 2 63.33 false',
      '2 Finalis 1 60.0 true',
      '3 Finalis 3 60.0 true',
    ]);
    expect(result.items.first.number, 2);
  });
}
