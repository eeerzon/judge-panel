// Judge session backed by `POST /judge/auth/login` (JWT bearer, ~1h expiry,
// no refresh endpoint → the judge signs in again). Scores entered while the
// session lapsed stay in the local draft store and sync after re-login.
//
// NOTE: the token is kept in SharedPreferences for now. Move it to secure
// storage (Keychain/Keystore) during the production security review.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/judge_api.dart';
import '../domain/models.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._(this._prefs, this._api);

  static const storageKey = 'kreenJudgeSession';

  final SharedPreferences? _prefs;
  final JudgeApi _api;

  String? _token;
  DateTime? _expiresAt;
  JudgeProfile? _judge;
  ActorType _actorType = ActorType.judge;

  /// Set when the session ended because the server rejected the token.
  String? expiredMessage;

  String? get token => hasJudgeSession ? _token : null;
  JudgeProfile? get judge => _judge;

  /// Workspaces this account may open (see [ActorType]).
  ActorType get actorType => _actorType;
  bool get canAdmin => _actorType.canAdmin;
  bool get canJudge => _actorType.canJudge;

  bool get hasJudgeSession =>
      _token != null && _judge != null && (_expiresAt == null || DateTime.now().isBefore(_expiresAt!));

  static Future<SessionStore> load(JudgeApi api) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final store = SessionStore._(prefs, api);
    try {
      final raw = prefs?.getString(storageKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        store._token = j['token'] as String?;
        store._expiresAt = DateTime.tryParse('${j['expiresAt']}');
        store._judge = JudgeProfile.fromJson(Map<String, dynamic>.from(j['judge'] as Map));
        store._actorType = ActorType.parse(j['actorType']);
      }
    } catch (_) {
      store._clear();
    }
    return store;
  }

  @visibleForTesting
  factory SessionStore.memory(JudgeApi api) => SessionStore._(null, api);

  /// Throws [ApiException] with the server message on failure.
  Future<void> login(String email, String password) async {
    final result = await _api.login(email.trim(), password);
    _token = result.accessToken;
    // Renew a minute early so a request never goes out with a dying token.
    _expiresAt = DateTime.now().add(result.expiresIn - const Duration(minutes: 1));
    _judge = result.judge;
    _actorType = result.actorType;
    expiredMessage = null;
    try {
      await _prefs?.setString(
        storageKey,
        jsonEncode({
          'token': _token,
          'expiresAt': _expiresAt!.toIso8601String(),
          'judge': _judge!.toJson(),
          'actorType': _actorType.name,
        }),
      );
    } catch (_) {}
    notifyListeners();
  }

  /// Ends the session on the device at once; a user Log Out also revokes the
  /// token on the server (`POST /judge/auth/logout`), so a copied token stops
  /// working too. Not when the server already rejected it ([reason]) or it
  /// has expired. Offline, the token stays valid until it expires.
  Future<void> logout({String? reason}) async {
    final revoke = reason == null && hasJudgeSession ? _token : null;
    _clear();
    if (revoke != null) {
      unawaited(_api.logout(revoke).catchError((Object _) {}));
    }
    expiredMessage = reason;
    try {
      await _prefs?.remove(storageKey);
    } catch (_) {}
    notifyListeners();
  }

  /// Wired to [ApiClient.onUnauthorized].
  void handleUnauthorized() {
    if (_token == null) return;
    logout(reason: 'Your session has ended. Please sign in again.');
  }

  void _clear() {
    _token = null;
    _expiresAt = null;
    _judge = null;
    _actorType = ActorType.judge;
  }
}
