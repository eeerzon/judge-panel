import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kreen_judge_mobile/api/api_client.dart';
import 'package:kreen_judge_mobile/api/judge_api.dart';
import 'package:kreen_judge_mobile/state/session_store.dart';

import 'support/fake_judge_api.dart';

void main() {
  test('Log Out revokes the token on the server; a rejected token is not sent again', () async {
    final api = FakeJudgeApi();
    final session = SessionStore.memory(api);
    await session.login('juri1@test.com', 'password123');
    await session.logout();
    expect(session.hasJudgeSession, isFalse);
    expect(api.loggedOut, ['token-juri1@test.com']);

    // 401 from the server (expired / revoked): nothing to revoke.
    await session.login('juri1@test.com', 'password123');
    session.handleUnauthorized();
    await Future<void>.delayed(Duration.zero);
    expect(api.loggedOut, hasLength(1));
  });

  test('logout request carries the given token, not the (cleared) session token', () async {
    http.Request? sent;
    final client = ApiClient(
      baseUrl: 'https://x',
      httpClient: MockClient((req) async {
        sent = req;
        return http.Response('{"success":true,"message":"Logout berhasil."}', 200);
      }),
    )..tokenProvider = () => null;
    await HttpJudgeApi(client).logout('abc');
    expect((sent!.method, sent!.url.path, sent!.headers['Authorization']), ('POST', '/judge/auth/logout', 'Bearer abc'));
  });
}
