import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kreen_judge_mobile/api/api_client.dart';

void main() {
  ApiClient client(http.Response response) => ApiClient(httpClient: MockClient((_) async => response), baseUrl: 'https://x');

  test('a 2xx page that is not API JSON (captive portal) is a network failure, not a save', () async {
    final api = client(http.Response('<html>Login to Wi-Fi</html>', 200, headers: {'content-type': 'text/html'}));
    await expectLater(
      api.post('/judge/rounds/7/score-sheet', {'scores': []}),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)),
    );
  });

  test('an empty 2xx body (204) is still a success', () async {
    expect(await client(http.Response('', 204)).delete('/judge/admin/judges/1'), isNull);
  });

  test('success:false in a 200 body is an error with the server message', () async {
    await expectLater(
      client(http.Response('{"success":false,"message":"Ditolak"}', 200)).get('/x'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Ditolak')),
    );
  });
}
