// Judge state: server data cached per round + a durable local draft/sync
// queue in front of `POST /judge/rounds/{id}/score-sheet`.
//
// RULE (CLAUDE.md §3): the total-score formula and status derivation live
// ONLY here. Screens call calculateContestantTotal()/getContestantStatus().
// The client total is display-only; the server remains authoritative.
//
// Offline-first (lite), per _docs/flutter/local-storage.md:
//   edit → local value + draft persisted → "Saving…" → debounced POST of the
//   dirty contestants → acknowledged → "Saved ✓". A network failure keeps the
//   draft ("Saved on device") and retries with backoff; it survives restarts.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/judge_api.dart';
import '../domain/models.dart';

enum SyncState { idle, syncing, synced, offline, error }

/// Per-contestant save indicator for the Scoring footer.
enum SaveIndicator { saved, saving, savedOnDevice, error, locked }

class RoundData {
  RoundData({required this.round, required this.contestants, required this.sections});

  Round round;
  List<Contestant> contestants;
  List<ScoringSection> sections;

  /// Scored leaf criteria, in display order.
  List<Criterion> get criteria => [for (final s in sections) ...s.criteria];

  /// Working values (server values overlaid with local drafts).
  final Map<int, Map<int, double?>> scores = {};

  /// Last values acknowledged by the server.
  final Map<int, Map<int, double?>> server = {};

  final Map<int, String> notes = {};
  final Map<int, String> sheetStatus = {};
}

class _Draft {
  final Map<int, Map<int, double?>> scores = {};
  final Map<int, String> notes = {};
  final Set<int> dirty = {};
  String? idempotencyKey;
  DateTime? submittedAt;

  bool get isEmpty => dirty.isEmpty && notes.isEmpty && idempotencyKey == null && submittedAt == null;

  Map<String, dynamic> toJson() => {
        'scores': {
          for (final e in scores.entries) '${e.key}': {for (final s in e.value.entries) '${s.key}': s.value},
        },
        'notes': {for (final e in notes.entries) '${e.key}': e.value},
        'dirty': dirty.toList(),
        'idempotencyKey': idempotencyKey,
        'submittedAt': submittedAt?.toIso8601String(),
      };

  static _Draft fromJson(Map<String, dynamic> j) {
    final d = _Draft();
    (j['scores'] as Map? ?? {}).forEach((cid, values) {
      final id = int.tryParse('$cid');
      if (id == null || values is! Map) return;
      d.scores[id] = {
        for (final e in values.entries)
          if (int.tryParse('${e.key}') != null) int.parse('${e.key}'): (e.value as num?)?.toDouble(),
      };
    });
    (j['notes'] as Map? ?? {}).forEach((cid, text) {
      final id = int.tryParse('$cid');
      if (id != null && text is String) d.notes[id] = text;
    });
    for (final c in (j['dirty'] as List? ?? const [])) {
      if (c is num) d.dirty.add(c.toInt());
    }
    d.idempotencyKey = j['idempotencyKey'] as String?;
    d.submittedAt = DateTime.tryParse('${j['submittedAt']}');
    return d;
  }
}

class JudgeStore extends ChangeNotifier {
  JudgeStore(this._api, [this._prefs, this.debounce = const Duration(milliseconds: 600)]);

  static Future<JudgeStore> create(JudgeApi api) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    return JudgeStore(api, prefs);
  }

  final JudgeApi _api;
  final SharedPreferences? _prefs;
  final Duration debounce;

  String? _judgeId;

  List<Round>? rounds;
  bool roundsLoading = false;
  DateTime? roundsLoadedAt;
  ApiException? roundsError;

  final Map<int, RoundData> _data = {};
  final Map<int, Future<void>> _loading = {};
  final Map<int, ApiException> _errors = {};

  final Map<int, _Draft> _drafts = {};
  final Map<int, Map<int, int>> _versions = {};
  final Map<int, Timer> _flushTimers = {};
  final Map<int, Future<bool>> _inFlight = {};
  Timer? _retryTimer;
  int _retryAttempt = 0;

  SyncState syncState = SyncState.idle;
  String? syncMessage;

  // ------------------------------------------------------------ lifecycle

  String get _draftKey => 'kreenJudgeDrafts.${_judgeId ?? 0}';

  /// Scopes caches and drafts to the signed-in judge (null = signed out).
  void bindJudge(String? judgeId) {
    if (judgeId == _judgeId) return;
    _reset();
    _judgeId = judgeId;
    if (judgeId == null) return;
    try {
      final raw = _prefs?.getString(_draftKey);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((rid, d) {
          final id = int.tryParse(rid);
          if (id != null && d is Map) _drafts[id] = _Draft.fromJson(Map<String, dynamic>.from(d));
        });
      }
    } catch (_) {}
  }

  void _reset() {
    for (final t in _flushTimers.values) {
      t.cancel();
    }
    _flushTimers.clear();
    _retryTimer?.cancel();
    rounds = null;
    roundsLoadedAt = null;
    roundsError = null;
    _data.clear();
    _loading.clear();
    _errors.clear();
    _drafts.clear();
    _versions.clear();
    _inFlight.clear();
    syncState = SyncState.idle;
    syncMessage = null;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _reset();
    super.dispose();
  }

  /// Background work (sync, reconcile) may finish after disposal.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> _persistDrafts() async {
    final prefs = _prefs;
    if (prefs == null || _judgeId == null) return;
    try {
      _drafts.removeWhere((_, d) => d.isEmpty);
      await prefs.setString(_draftKey, jsonEncode({for (final e in _drafts.entries) '${e.key}': e.value.toJson()}));
    } catch (_) {}
  }

  /// Dev control: drop unsent local drafts for the current judge.
  Future<void> clearLocalDrafts() async {
    _drafts.clear();
    await _persistDrafts();
    final ids = _data.keys.toList();
    _data.clear();
    notifyListeners();
    for (final id in ids) {
      unawaited(ensureRound(id));
    }
  }

  // --------------------------------------------------------------- loading

  Future<void> loadRounds() async {
    roundsLoading = true;
    notifyListeners();
    try {
      rounds = await _api.rounds();
      roundsLoadedAt = DateTime.now();
      roundsError = null;
      if (syncState == SyncState.offline) syncState = SyncState.idle;
    } on ApiException catch (e) {
      roundsError = e;
      if (e.isNetwork) syncState = SyncState.offline;
    } finally {
      roundsLoading = false;
      notifyListeners();
    }
    // Card progress on My Rounds needs each round's (fresh) sheet.
    for (final r in rounds ?? const <Round>[]) {
      unawaited(ensureRound(r.id, force: true));
    }
  }

  /// My Rounds entry: skip the fetch if the Splash just did it (or is doing it).
  Future<void> refreshRoundsIfStale([Duration maxAge = const Duration(seconds: 10)]) async {
    final at = roundsLoadedAt;
    if (roundsLoading || (at != null && DateTime.now().difference(at) < maxAge)) return;
    await loadRounds();
  }

  RoundData? data(int roundId) => _data[roundId];
  bool isLoading(int roundId) => _loading.containsKey(roundId);
  ApiException? errorFor(int roundId) => _errors[roundId];

  /// Fetches round + contestants + criteria + score-sheet (in parallel) and
  /// overlays unsent local drafts.
  /// Concurrent callers share the in-flight load.
  Future<void> ensureRound(int roundId, {bool force = false}) {
    final inFlight = _loading[roundId];
    if (inFlight != null) return inFlight;
    if (!force && _data.containsKey(roundId)) return Future.value();
    final future = _loadRound(roundId);
    _loading[roundId] = future;
    return future;
  }

  Future<void> _loadRound(int roundId) async {
    _errors.remove(roundId);
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.round(roundId),
        _api.contestants(roundId),
        _api.criteria(roundId),
        _api.scoreSheet(roundId),
      ]);
      final listed = rounds?.where((r) => r.id == roundId).firstOrNull;
      final round = (results[0] as Round).withEventName(listed?.eventName, listed?.eventBanner, listed?.eventId);
      final sheet = results[3] as List<ScoreSheetRow>;
      final names = {for (final r in sheet) r.contestantId: r.name};
      final data = RoundData(
        round: round,
        contestants: [for (final c in results[1] as List<Contestant>) c.copyWithName(names[c.id])],
        sections: buildSections(results[2] as List<Criterion>),
      );
      _applySheet(data, sheet, roundId);
      _data[roundId] = data;
    } on ApiException catch (e) {
      _errors[roundId] = e;
      if (e.isNetwork) syncState = SyncState.offline;
    } finally {
      _loading.remove(roundId);
      notifyListeners();
    }
    if (_drafts[roundId]?.dirty.isNotEmpty ?? false) _scheduleFlush(roundId);
  }

  void _applySheet(RoundData data, List<ScoreSheetRow> sheet, int roundId) {
    final draft = _drafts[roundId];
    final rows = {for (final r in sheet) r.contestantId: r};
    for (final c in data.contestants) {
      final row = rows[c.id];
      final server = {for (final k in data.criteria) k.id: row?.scores[k.id]};
      data.server[c.id] = Map.of(server);
      data.sheetStatus[c.id] = row?.sheetStatus ?? 'not_started';
      final locked = kLockedSheetStatuses.contains(data.sheetStatus[c.id]);
      if (locked) draft?.dirty.remove(c.id); // a locked sheet can never accept the draft
      final useDraft = draft != null && draft.dirty.contains(c.id);
      data.scores[c.id] = useDraft ? {...server, ...?draft.scores[c.id]} : server;
      data.notes[c.id] = (useDraft ? draft.notes[c.id] : null) ?? row?.comment ?? draft?.notes[c.id] ?? '';
    }
  }

  /// `POST /review` returns the same rows as the score sheet; refresh the
  /// statuses/values the Review screen shows (never overwriting drafts).
  Future<void> refreshReview(int roundId) async {
    final data = _data[roundId];
    if (data == null) return ensureRound(roundId);
    try {
      _applySheet(data, await _api.review(roundId), roundId);
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isNetwork) {
        syncState = SyncState.offline;
        notifyListeners();
      }
    }
  }

  // --------------------------------------------------------------- queries

  /// Event title (`vote.judul_vote`) of the round's own event — a judge can
  /// have rounds of several events. Without a round: the first one listed.
  String eventName([int? roundId]) {
    if (roundId != null) {
      final listed = rounds?.where((r) => r.id == roundId).firstOrNull;
      final name = getRound(roundId)?.eventName ?? listed?.eventName;
      if (name != null) return name;
    }
    return rounds?.map((r) => r.eventName).whereType<String>().firstOrNull ?? 'KREEN Judging';
  }

  int eventYear([int? roundId]) {
    final r = roundId == null ? rounds?.firstOrNull : getRound(roundId);
    return (r?.openedAt ?? r?.createdAt ?? DateTime.now()).year;
  }

  Round? getRound(int roundId) => _data[roundId]?.round ?? rounds?.where((r) => r.id == roundId).firstOrNull;

  List<Contestant> contestantsOf(int roundId) => _data[roundId]?.contestants ?? const [];

  Contestant? getContestant(int roundId, int contestantId) =>
      contestantsOf(roundId).where((c) => c.id == contestantId).firstOrNull;

  double? getScore(int roundId, int contestantId, int criterionId) =>
      _data[roundId]?.scores[contestantId]?[criterionId];

  /// FR-1: status is always derived from the number of filled criteria.
  StatusInfo getContestantStatus(int roundId, int contestantId) {
    final data = _data[roundId];
    final criteria = data?.criteria ?? const <Criterion>[];
    final scores = data?.scores[contestantId] ?? const {};
    final scoredCount = criteria.where((c) => scores[c.id] != null).length;
    if (scoredCount == 0) return StatusInfo(ScoreStatus.notStarted, 0, criteria.length);
    if (scoredCount == criteria.length) return StatusInfo(ScoreStatus.scored, scoredCount, criteria.length);
    return StatusInfo(ScoreStatus.draft, scoredCount, criteria.length);
  }

  bool isContestantComplete(int roundId, int contestantId) =>
      getContestantStatus(roundId, contestantId).status == ScoreStatus.scored;

  /// FR-2 generalised to server criteria ranges: each criterion contributes
  /// (raw / max_points) × weight, normalised so the total is out of 100.
  /// On the prototype rubric (1–10, weights summing to 100) this is exactly
  /// Σ(value × weight) / 10. Null until EVERY criterion is filled — an empty
  /// criterion is never zero and a partial total is never shown.
  double? calculateContestantTotal(int roundId, int contestantId) {
    if (!isContestantComplete(roundId, contestantId)) return null;
    final data = _data[roundId]!;
    final criteria = data.criteria;
    final weightSum = criteria.fold<double>(0, (s, c) => s + c.weight);
    if (criteria.isEmpty || weightSum <= 0) return null;
    var sum = 0.0;
    for (final c in criteria) {
      if (c.max <= 0) continue;
      sum += data.scores[contestantId]![c.id]! / c.max * c.weight;
    }
    return sum * 100 / weightSum;
  }

  StatusCounts countByStatus(int roundId) {
    var scored = 0, draft = 0, notStarted = 0;
    final contestants = contestantsOf(roundId);
    for (final c in contestants) {
      switch (getContestantStatus(roundId, c.id).status) {
        case ScoreStatus.scored:
          scored++;
        case ScoreStatus.draft:
          draft++;
        case ScoreStatus.notStarted:
          notStarted++;
      }
    }
    return StatusCounts(scored: scored, draft: draft, notStarted: notStarted, total: contestants.length);
  }

  bool areAllContestantsComplete(int roundId) {
    final counts = countByStatus(roundId);
    return counts.total > 0 && counts.scored == counts.total;
  }

  /// Submitted = the server reports every contestant sheet as locked.
  bool isSubmitted(int roundId) {
    final data = _data[roundId];
    if (data == null || data.contestants.isEmpty) return false;
    return data.contestants.every((c) => kLockedSheetStatuses.contains(data.sheetStatus[c.id]));
  }

  bool isReopened(int roundId) => _data[roundId]?.sheetStatus.values.contains('reopened') ?? false;

  bool isContestantLocked(int roundId, int contestantId) =>
      kLockedSheetStatuses.contains(_data[roundId]?.sheetStatus[contestantId]);

  /// Local time of this device's acknowledged submit (the API returns none).
  DateTime? submittedAt(int roundId) => _drafts[roundId]?.submittedAt;

  bool canJudgeRound(int roundId) {
    final round = getRound(roundId);
    return round != null && round.status == RoundStatus.open && !isSubmitted(roundId);
  }

  String getNote(int roundId, int contestantId) => _data[roundId]?.notes[contestantId] ?? '';

  bool hasPending(int roundId) => _drafts[roundId]?.dirty.isNotEmpty ?? false;

  SaveIndicator saveIndicator(int roundId, int contestantId) {
    if (isContestantLocked(roundId, contestantId)) return SaveIndicator.locked;
    final dirty = _drafts[roundId]?.dirty.contains(contestantId) ?? false;
    if (!dirty) return SaveIndicator.saved;
    return switch (syncState) {
      SyncState.offline => SaveIndicator.savedOnDevice,
      SyncState.error => SaveIndicator.error,
      _ => SaveIndicator.saving,
    };
  }

  ConnectionStateKind get connectionState => switch (syncState) {
        SyncState.syncing => ConnectionStateKind.syncing,
        SyncState.offline => ConnectionStateKind.offline,
        SyncState.synced => ConnectionStateKind.synced,
        _ => ConnectionStateKind.online,
      };

  /// Official result for Judges. The server enforces visibility (403 until
  /// the admin publishes it); the client never computes rankings.
  Future<ResultSnapshot> fetchResults(int roundId) => _api.results(roundId);

  // -------------------------------------------------------------- commands

  _Draft _draftFor(int roundId) => _drafts.putIfAbsent(roundId, _Draft.new);

  void _markDirty(int roundId, int contestantId) {
    final data = _data[roundId]!;
    final draft = _draftFor(roundId)
      ..dirty.add(contestantId)
      ..scores[contestantId] = Map.of(data.scores[contestantId] ?? const {})
      ..notes[contestantId] = data.notes[contestantId] ?? '';
    draft.idempotencyKey = null; // content changed → a new submit attempt
    final versions = _versions.putIfAbsent(roundId, () => {});
    versions[contestantId] = (versions[contestantId] ?? 0) + 1;
    unawaited(_persistDrafts());
    notifyListeners();
    _scheduleFlush(roundId);
  }

  /// Writes one criterion value (null clears it). Returns false when the
  /// sheet is locked or the round is not open.
  bool setScore(int roundId, int contestantId, int criterionId, double? value) {
    final data = _data[roundId];
    if (data == null || !canJudgeRound(roundId) || isContestantLocked(roundId, contestantId)) return false;
    data.scores.putIfAbsent(contestantId, () => {})[criterionId] = value;
    _markDirty(roundId, contestantId);
    return true;
  }

  bool setNote(int roundId, int contestantId, String text) {
    final data = _data[roundId];
    if (data == null || !canJudgeRound(roundId) || isContestantLocked(roundId, contestantId)) return false;
    data.notes[contestantId] = text;
    _markDirty(roundId, contestantId);
    return true;
  }

  void _scheduleFlush(int roundId, [Duration? delay]) {
    _flushTimers[roundId]?.cancel();
    _flushTimers[roundId] = Timer(delay ?? debounce, () => flush(roundId));
  }

  /// Sends every dirty contestant of the round. Returns true when nothing is
  /// left pending. A save already in flight is awaited first (Submit right
  /// after an edit must not fail just because autosave is running).
  Future<bool> flush(int roundId) async {
    _flushTimers.remove(roundId)?.cancel();
    for (var running = _inFlight[roundId]; running != null; running = _inFlight[roundId]) {
      await running;
    }
    final data = _data[roundId];
    final draft = _drafts[roundId];
    if (data == null || draft == null || draft.dirty.isEmpty) return true;
    final done = Completer<bool>();
    _inFlight[roundId] = done.future;
    try {
      final result = await _send(roundId, data, draft);
      done.complete(result);
      return result;
    } catch (e) {
      done.complete(false);
      rethrow;
    }
  }

  Future<bool> _send(int roundId, RoundData data, _Draft draft) async {
    final sentVersions = <int, int>{};
    final sentValues = <int, Map<int, double?>>{};
    final payload = <ScoreInput>[];
    for (final cid in draft.dirty.toList()) {
      final note = data.notes[cid]?.trim();
      final rows = <ScoreInput>[
        for (final c in data.criteria)
          if (data.scores[cid]?[c.id] != null || data.server[cid]?[c.id] != null)
            ScoreInput(
              contestantId: cid,
              criterionId: c.id,
              rawScore: data.scores[cid]?[c.id],
              comment: note == null || note.isEmpty ? null : note,
            ),
      ];
      if (rows.isEmpty) {
        // Nothing to send yet (e.g. a note before any score) — the note stays
        // in the local draft and goes out with the first score.
        draft.dirty.remove(cid);
        continue;
      }
      payload.addAll(rows);
      sentVersions[cid] = _versions[roundId]?[cid] ?? 0;
      sentValues[cid] = Map.of(data.scores[cid] ?? const {});
    }
    if (payload.isEmpty) {
      _inFlight.remove(roundId);
      await _persistDrafts();
      notifyListeners();
      return true;
    }

    syncState = SyncState.syncing;
    notifyListeners();
    try {
      await _api.saveScores(roundId, payload);
      sentValues.forEach((cid, values) {
        data.server[cid] = values;
        if ((_versions[roundId]?[cid] ?? 0) == sentVersions[cid]) draft.dirty.remove(cid);
      });
      _retryAttempt = 0;
      syncState = SyncState.synced;
      syncMessage = null;
    } on ApiException catch (e) {
      if (e.isNetwork) {
        syncState = SyncState.offline;
        syncMessage = e.message;
        _scheduleRetry();
      } else if ((e.statusCode ?? 0) >= 500) {
        // Server hiccup: keep the draft and retry, like a network failure.
        syncState = SyncState.error;
        syncMessage = e.message;
        _scheduleRetry();
      } else {
        syncState = SyncState.error;
        syncMessage = e.message;
        // Locked / not assigned / validation → re-sync with the server state.
        if (e.isValidation || e.isForbidden) unawaited(_reconcile(roundId));
      }
    } finally {
      _inFlight.remove(roundId);
      await _persistDrafts();
      notifyListeners();
    }
    if (draft.dirty.isNotEmpty && syncState == SyncState.synced) _scheduleFlush(roundId);
    return draft.dirty.isEmpty;
  }

  Future<void> _reconcile(int roundId) async {
    try {
      final data = _data[roundId];
      if (data == null) return;
      _applySheet(data, await _api.scoreSheet(roundId), roundId);
      await _persistDrafts();
      notifyListeners();
    } on ApiException catch (_) {}
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final seconds = math.min(60, 5 * (1 << math.min(_retryAttempt, 4)));
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds), flushAll);
  }

  Future<void> flushAll() async {
    for (final id in _drafts.keys.toList()) {
      if (_drafts[id]?.dirty.isNotEmpty ?? false) await flush(id);
    }
  }

  /// Returns null on success, otherwise a message for the submit dialog.
  /// Completeness is re-checked here — the disabled button is not the guard.
  Future<String?> submitJudging(int roundId) async {
    if (!canJudgeRound(roundId)) return 'This round is not open for scoring.';
    if (!areAllContestantsComplete(roundId)) return 'Complete all contestants before submitting.';
    if (!await flush(roundId)) {
      return syncMessage ?? 'Some scores are not saved to the server yet. Please try again.';
    }
    final draft = _draftFor(roundId);
    // Stable key: an ambiguous failure is retried with the same key.
    draft.idempotencyKey ??= _newIdempotencyKey();
    await _persistDrafts();
    try {
      await _api.submit(roundId, draft.idempotencyKey!);
    } on ApiException catch (e) {
      if (!e.isNetwork) unawaited(_reconcile(roundId));
      return e.message;
    }
    draft
      ..idempotencyKey = null
      ..submittedAt = DateTime.now();
    final data = _data[roundId];
    if (data != null) {
      for (final c in data.contestants) {
        data.sheetStatus[c.id] = 'submitted'; // acknowledged by the server
      }
    }
    await _persistDrafts();
    notifyListeners();
    unawaited(_reconcile(roundId));
    return null;
  }

  static String _newIdempotencyKey() {
    final r = math.Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
