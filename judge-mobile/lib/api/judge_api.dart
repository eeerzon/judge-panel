// Judge endpoints (`/api/v1/judge/...`). Admin endpoints will get their own
// class later; keep this one Judge-only.

import '../domain/models.dart';
import 'api_client.dart';

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.expiresIn,
    required this.judge,
    this.actorType = ActorType.judge,
  });
  final String accessToken;
  final Duration expiresIn;
  final JudgeProfile judge;
  final ActorType actorType;
}

abstract class JudgeApi {
  Future<LoginResult> login(String email, String password);
  Future<List<Round>> rounds();
  Future<Round> round(String roundId);
  Future<List<Contestant>> contestants(String roundId);
  Future<List<Criterion>> criteria(String roundId);
  Future<List<ScoreSheetRow>> scoreSheet(String roundId);
  Future<void> saveScores(String roundId, List<ScoreInput> scores);
  Future<List<ScoreSheetRow>> review(String roundId);
  Future<void> submit(String roundId, String idempotencyKey);
  Future<ResultSnapshot> results(String roundId);
}

class HttpJudgeApi implements JudgeApi {
  HttpJudgeApi(this.client);
  final ApiClient client;

  static List<Map<String, dynamic>> _list(dynamic data) => [
        if (data is List)
          for (final e in data)
            if (e is Map) Map<String, dynamic>.from(e),
      ];

  static Map<String, dynamic> _map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};

  @override
  Future<LoginResult> login(String email, String password) async {
    final data = _map(await client.post('/judge/auth/login', {'email': email, 'password': password}));
    final token = data['access_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Login response did not include an access token.');
    }
    final expires = data['expires_in'];
    final seconds = expires is num ? expires.toInt() : int.tryParse('$expires') ?? 3600;
    return LoginResult(
      accessToken: token,
      expiresIn: Duration(seconds: seconds),
      judge: JudgeProfile.fromJson(_map(data['judge'])),
      actorType: ActorType.parse(data['actor_type']),
    );
  }

  @override
  Future<List<Round>> rounds() async =>
      _list(await client.get('/judge/rounds')).map(Round.fromJson).toList()
        // Ids are opaque hashes now: ties fall back to creation time.
        ..sort((a, b) => a.orderNo != b.orderNo
            ? a.orderNo.compareTo(b.orderNo)
            : (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

  @override
  Future<Round> round(String roundId) async => Round.fromJson(_map(await client.get('/judge/rounds/$roundId')));

  @override
  Future<List<Contestant>> contestants(String roundId) async => _list(await client.get('/judge/rounds/$roundId/contestants'))
      .where((j) => '${j['status'] ?? 'active'}'.toLowerCase() == 'active')
      .map(Contestant.fromJson)
      .toList()
    ..sort((a, b) => a.number != b.number ? a.number.compareTo(b.number) : a.id.compareTo(b.id));

  /// Sub-criteria may come nested in `children`; scoring sections need the
  /// flat list (parent, then its children with `parent_id`).
  static List<Map<String, dynamic>> _flatCriteria(Object? data, [Object? parentId]) {
    final out = <Map<String, dynamic>>[];
    for (final c in _list(data)) {
      final children = c.remove('children');
      out.add({...c, if (c['parent_id'] == null && parentId != null) 'parent_id': parentId});
      out.addAll(_flatCriteria(children, c['id']));
    }
    return out;
  }

  @override
  Future<List<Criterion>> criteria(String roundId) async => _flatCriteria(await client.get('/judge/rounds/$roundId/criteria'))
      .where((j) => j['flag_aktif'] != false)
      .map(Criterion.fromJson)
      .toList();

  @override
  Future<List<ScoreSheetRow>> scoreSheet(String roundId) async =>
      _list(await client.get('/judge/rounds/$roundId/score-sheet')).map(ScoreSheetRow.fromJson).toList();

  @override
  Future<void> saveScores(String roundId, List<ScoreInput> scores) async {
    await client.post('/judge/rounds/$roundId/score-sheet', {'scores': [for (final s in scores) s.toJson()]});
  }

  @override
  Future<List<ScoreSheetRow>> review(String roundId) async =>
      _list(await client.post('/judge/rounds/$roundId/review')).map(ScoreSheetRow.fromJson).toList();

  @override
  Future<void> submit(String roundId, String idempotencyKey) async {
    await client.post('/judge/rounds/$roundId/submit', {'idempotency_key': idempotencyKey});
  }

  @override
  Future<ResultSnapshot> results(String roundId) async =>
      ResultSnapshot.fromJson(_map(await client.get('/judge/rounds/$roundId/results')));
}
