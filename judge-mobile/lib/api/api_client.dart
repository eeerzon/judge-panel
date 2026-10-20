// Thin JSON-over-HTTP client for the KREEN API.
//
// Every response uses `{success, message?, data?}`; errors come back as
// `{message, errors?}` with 401 (unauthenticated / bad login), 403 (not
// assigned / not visible) or 422 (validation, locked sheet).

import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;

import 'package:http/http.dart' as http;

/// Override per build: `--dart-define=KREEN_API_BASE_URL=https://.../api/v1`
const kApiBaseUrl = String.fromEnvironment(
  'KREEN_API_BASE_URL',
  defaultValue: 'https://newvote.kreenconnect.com/api/v1', //staging
  // defaultValue: 'https://vote.kreen.asia/api/v1', //live
);

const kPublicResultsBaseUrl = String.fromEnvironment(
  'KREEN_PUBLIC_RESULTS_URL', 
  defaultValue: 'https://judge.kreen.asia'
);

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  /// No response at all (offline, DNS, timeout).
  const ApiException.network([this.message = 'No connection. Please check the network and try again.'])
      : statusCode = null,
        fieldErrors = const {};

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isNetwork => statusCode == null;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    this.baseUrl = kApiBaseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  final Duration timeout;

  /// Bearer token supplier (set by the session).
  String? Function() tokenProvider = () => null;

  /// Called when an authenticated request gets 401 (token expired/revoked).
  void Function() onUnauthorized = () {};

  Future<dynamic> get(String path) async => (await _send('GET', path))?['data'];

  /// Whole JSON body (for responses with fields next to `data`, e.g. `meta`).
  Future<Map<String, dynamic>> getEnvelope(String path) async => await _send('GET', path) ?? const {};

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async => (await _send('POST', path, body))?['data'];

  /// POST with [token] instead of the session's (e.g. logout, sent after the
  /// session was already cleared on the device).
  Future<dynamic> postWithToken(String path, String token) async =>
      (await _send('POST', path, null, token))?['data'];

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async => (await _send('PATCH', path, body))?['data'];

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async => (await _send('PUT', path, body))?['data'];

  Future<dynamic> delete(String path) async => (await _send('DELETE', path))?['data'];

  /// Returns the decoded body of a successful response.
  Future<Map<String, dynamic>?> _send(String method, String path, [Map<String, dynamic>? body, String? tokenOverride]) async {
    final token = tokenOverride ?? tokenProvider();
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      // The timeout covers the body too, not only the response headers.
      response = await _http.send(request).then(http.Response.fromStream).timeout(timeout);
    } on TimeoutException {
      throw const ApiException.network('The server took too long to respond. Please try again.');
    } on IOException {
      // SocketException, TLS handshake (TlsException), HttpException…
      throw const ApiException.network();
    } on http.ClientException {
      throw const ApiException.network();
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {}

    final success = response.statusCode >= 200 && response.statusCode < 300;
    // A 2xx body that is not the API's JSON (e.g. a Wi-Fi captive portal
    // page) is not an acknowledgement: never let it clear a pending draft.
    if (success && json == null && response.bodyBytes.isNotEmpty) {
      throw const ApiException.network('Unexpected response from the server. Check the network and try again.');
    }
    if (success && json?['success'] != false) return json;

    final message = (json?['message'] as String?)?.trim();
    final errors = <String, List<String>>{};
    final rawErrors = json?['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((k, v) => errors['$k'] = [if (v is List) ...v.map((e) => '$e') else '$v']);
    }
    final error = ApiException(
      message?.isNotEmpty == true ? message! : 'Request failed (${response.statusCode}).',
      statusCode: response.statusCode,
      fieldErrors: errors,
    );
    // Also without a token: after the 1-hour expiry the session stops sending
    // it, and the 401 must still end the session (back to Login) instead of
    // leaving every action failing with "Unauthenticated.". A wrong password
    // on Login is ignored by the session (it has no token then).
    if (error.isUnauthorized) onUnauthorized();
    throw error;
  }
}
