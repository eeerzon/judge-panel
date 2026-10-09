// Admin state + rules — port of judge-prototype/admin/admin-domain.js
// (with the seed data of admin-data.js). This is the ONLY place for Admin
// rules: effective scored weight, readiness, open/close guards, governance
// (reopen / excuse / restore / remove), result calculation, finalize,
// visibility and advancement.
//
// With an [AdminApi] (the app), Admin works per event: the event list,
// event detail, rounds (list + create), the contestant master (read) and the
// judge master (CRUD) come from `/judge/admin/...`; the API is the authority
// for those on every load.
// Everything the API does not expose yet (round assignments, criteria,
// monitoring, score sheets, results, governance, advancement, audit) is
// prototype data, sized from the API round counts and kept per event on the
// device (SharedPreferences `kreenAdminConfiguration.<idVote>`). Without an
// API (tests) the store runs on the HTML prototype seed.
// When more Admin endpoints exist, replace the matching command bodies with
// API calls; screens only use this class's public surface. Backend must
// remain the authority for every rule (_docs/api/api-boundary.md).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/admin_api.dart';
import '../api/api_client.dart';
import 'admin_models.dart';

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
double _dbl(Object? v, double fallback) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

class AdminStore extends ChangeNotifier {
  AdminStore._(this._prefs, [this._api]);

  static const storageKey = 'kreenAdminConfiguration';
  static const schemaVersion = 5;

  final SharedPreferences? _prefs;
  final AdminApi? _api;

  /// Backed by the Admin API (an event must be chosen first).
  bool get connected => _api != null;

  /// Name recorded as actor in audit/governance (the signed-in account).
  String actor = 'Super Admin';
  String actorRole = 'Super Admin';

  // ---------------------------------------------------------------- state

  late List<AdminRound> rounds;
  late List<ContestantMaster> _contestants;
  late List<JudgeMaster> _judges;
  late Map<int, List<int>> _contestantAssignments;
  late Map<int, List<JudgeAssignment>> _judgeAssignments;
  late Map<int, List<AdminCriterion>> _criteriaByRound;
  late Map<int, List<ReopenRecord>> _reopensByRound;
  late Map<int, Map<int, ({String status, DateTime? submittedAt})>> _submissionOverrides;
  late List<AuditEvent> _auditEvents;
  late Map<int, RoundResult> _snapshots;
  late Map<int, bool> _visibility;
  late Map<int, bool> _tieAcknowledged;
  late Map<int, Advancement> _advancementBySource;
  late List<Map<String, dynamic>> _advancementHistory;
  late EventSettings eventSettings;

  static Future<AdminStore> load({AdminApi? api}) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final store = AdminStore._(prefs, api).._seed();
    if (api != null) return store; // state is loaded per event (openEvent)
    try {
      final raw = prefs?.getString(storageKey);
      if (raw != null) store._restore(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      store._seed();
    }
    return store;
  }

  /// In-memory store (tests, or when storage is unavailable).
  factory AdminStore.memory({AdminApi? api}) => AdminStore._(null, api).._seed();

  // --------------------------------------------------------------- events (API)

  /// The event being managed; null until one is chosen (API mode only).
  AdminEvent? event;
  bool get needsEvent => connected && event == null;

  List<AdminEvent> events = const [];
  int eventsPage = 0, eventsLastPage = 1, eventsTotal = 0;
  String eventsSearch = '';
  bool eventsLoading = false;
  String? eventsError;
  bool get hasMoreEvents => eventsPage < eventsLastPage;
  int _eventsRequest = 0;

  /// `GET /judge/admin/dashboard` — first page for [search], or the next page.
  Future<void> loadEvents({String? search, bool more = false}) async {
    final api = _api;
    if (api == null || (more && (eventsLoading || !hasMoreEvents))) return;
    if (search != null) eventsSearch = search.trim();
    final request = ++_eventsRequest;
    final page = more ? eventsPage + 1 : 1;
    eventsLoading = true;
    eventsError = null;
    notifyListeners();
    try {
      final result = await api.events(page: page, search: eventsSearch.isEmpty ? null : eventsSearch);
      if (request != _eventsRequest) return; // a newer search replaced this one
      events = more ? [...events, ...result.items] : result.items;
      eventsPage = result.currentPage;
      eventsLastPage = result.lastPage;
      eventsTotal = result.total;
    } on ApiException catch (e) {
      if (request == _eventsRequest) eventsError = e.message;
    } finally {
      if (request == _eventsRequest) {
        eventsLoading = false;
        notifyListeners();
      }
    }
  }

  /// Server-side judging rules of the open event (null = not loaded).
  ServerEventSettings? serverSettings;

  /// `PATCH /judge/admin/events/{idVote}/settings`.
  Future<String?> saveServerSettings(ServerEventSettings settings) async {
    final api = _api, current = event;
    if (api == null || current == null) return _notConnected;
    try {
      await api.updateEventSettings(current.id, settings);
      serverSettings = await api.eventSettings(current.id);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.fieldErrors.values.expand((m) => m).firstOrNull ?? e.message;
    }
  }

  /// `GET /create-vote/themes` raw items; null when unavailable.
  Future<List<Map<String, dynamic>>?> fetchThemes() async {
    try {
      return await _api?.themes();
    } on ApiException {
      return null;
    }
  }

  /// Event currently being opened (drives the loading state of the list).
  String? openingEventId;
  AdminEventDetail? _lastDetail;
  List<Map<String, dynamic>> _lastContestants = const [];
  List<Map<String, dynamic>> _lastJudges = const [];

  /// Loads `GET /judge/admin/events/{idVote}` + its contestants and makes it
  /// the managed event. Returns an error message, or null on success.
  Future<String?> openEvent(String idVote) async {
    final api = _api;
    if (api == null) return 'Admin API is not available.';
    openingEventId = idVote;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([api.event(idVote), api.contestants(idVote), api.judges()]);
      try {
        serverSettings = await api.eventSettings(idVote);
      } on ApiException {
        serverSettings = null; // optional: Settings shows it as unavailable
      }
      _applyEvent(
        results[0] as AdminEventDetail,
        results[1] as List<Map<String, dynamic>>,
        results[2] as List<Map<String, dynamic>>,
      );
      // Round data is small; load every round so Overview/Rounds are real.
      await Future.wait([for (final r in [...rounds]) loadRound(r.id)]);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      openingEventId = null;
      notifyListeners();
    }
  }

  /// Reloads the managed event from the API.
  Future<String?> refreshEvent() async => event == null ? null : openEvent(event!.id);

  /// Session ended: forget the account's event list and the open event.
  void clearSession() {
    _eventsRequest++;
    events = const [];
    eventsPage = 0;
    eventsLastPage = 1;
    eventsTotal = 0;
    eventsSearch = '';
    eventsLoading = false;
    eventsError = null;
    closeEvent();
  }

  /// Leaves the event (back to the event list).
  void closeEvent() {
    event = null;
    _lastDetail = null;
    notifyListeners();
  }

  /// `POST /judge/admin/events/{idVote}/rounds`, then reloads the event.
  Future<AdminActionResult> createRound({
    required String name,
    required String promoteMode,
    required int promoteTopN,
    required bool favoritPromoteEnabled,
  }) async {
    final api = _api, current = event;
    if (api == null || current == null) {
      return const AdminActionResult.fail('Round creation is not available yet in this prototype.');
    }
    try {
      await api.createRound(current.id,
          name: name.trim(),
          promoteMode: promoteMode,
          promoteTopN: promoteTopN,
          favoritPromoteEnabled: favoritPromoteEnabled);
    } on ApiException catch (e) {
      return AdminActionResult.fail(e.fieldErrors.values.expand((m) => m).firstOrNull ?? e.message);
    }
    final error = await refreshEvent();
    return error == null ? const AdminActionResult.ok() : AdminActionResult.fail(error);
  }

  String get _storageKey => event == null ? storageKey : '$storageKey.${event!.id}';

  void _applyEvent(AdminEventDetail detail, List<Map<String, dynamic>> contestants, List<Map<String, dynamic>> judges) {
    if (event?.id != detail.event.id) {
      // New event: empty prototype state, then whatever was kept on device.
      _seed();
      rounds = [];
      _contestants = [];
      _judges = [];
      _contestantAssignments = {};
      _judgeAssignments = {};
      _criteriaByRound = {};
      event = detail.event;
      try {
        final raw = _prefs?.getString(_storageKey);
        if (raw != null) _restore(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    event = detail.event;
    _lastDetail = detail;
    _lastContestants = contestants;
    _lastJudges = judges;
    _mergeContestants(contestants);
    _mergeJudges(judges);
    _applyRounds(detail.rounds);
    final year = detail.event.grandFinalOn ?? detail.event.votingOpensAt;
    eventSettings = eventSettings.copyWith(
      eventName: detail.event.title,
      shortName: detail.event.title,
      eventYear: year == null ? eventSettings.eventYear : '${year.year}',
    );
    _save();
  }

  /// API contestants replace their local copies; local ids stay stable per
  /// `id_finalis`. Contestants added on the device (no API yet) are kept.
  void _mergeContestants(List<Map<String, dynamic>> raw) {
    final byExternal = {for (final c in _contestants) if (c.externalId != null) c.externalId!: c};
    var nextId = nextContestantId();
    final merged = <ContestantMaster>[
      for (final j in raw)
        () {
          final existing = byExternal['${j['id_finalis']}'];
          final item = ContestantMaster.fromApi(j, id: existing?.id ?? nextId++);
          if (existing != null) item.status = existing.status; // no status in the API yet
          return item;
        }(),
      ..._contestants.where((c) => c.externalId == null),
    ]..sort((a, b) => a.number.compareTo(b.number));
    _contestants = merged;
  }

  // ------------------------------------------------------ round data (API)

  /// Per round: local contestant id → `round_contestant` id.
  final Map<int, Map<int, int>> _roundContestantIds = {};

  /// Per round: judge progress from `GET rounds/{id}/monitoring`.
  final Map<int, Map<int, _JudgeProgress>> _progress = {};

  /// Closed rounds: provisional result from `GET rounds/{id}/results`.
  final Map<int, RoundResult> _provisional = {};

  /// Finalized source rounds: `GET rounds/{id}/advancement`.
  final Map<int, AdvancementInfo> _advancementInfo = {};

  final Set<int> _loadedRounds = {};
  final Set<int> loadingRounds = {};
  final Map<int, String> roundErrors = {};

  bool isRoundLoaded(int roundId) => !connected || _loadedRounds.contains(roundId);
  AdvancementInfo? advancementInfo(int roundId) => _advancementInfo[roundId];

  /// Loads everything the Admin API has for one round and replaces the local
  /// copies. Returns an error message, or null.
  Future<String?> loadRound(int roundId) async {
    final api = _api;
    if (api == null) return null;
    loadingRounds.add(roundId);
    notifyListeners();
    try {
      final round = await api.round(roundId);
      final done = round.status == 'closed' || round.status == 'finalized';
      final parts = await Future.wait<Object?>([
        api.roundContestants(roundId),
        api.roundJudges(roundId),
        api.criteria(roundId),
        api.monitoring(roundId),
        done ? api.results(roundId) : Future<Object?>.value(),
        round.status == 'finalized' ? api.advancement(roundId) : Future<Object?>.value(),
      ]);
      _applyRound(
        round,
        contestants: parts[0] as List<Map<String, dynamic>>,
        judges: parts[1] as List<Map<String, dynamic>>,
        criteria: parts[2] as List<Map<String, dynamic>>,
        monitoring: parts[3] as Map<String, dynamic>,
        results: parts[4] as Map<String, dynamic>?,
        advancement: parts[5] as Map<String, dynamic>?,
      );
      roundErrors.remove(roundId);
      return null;
    } on ApiException catch (e) {
      roundErrors[roundId] = e.message;
      return e.message;
    } finally {
      loadingRounds.remove(roundId);
      _save();
    }
  }

  ContestantMaster _contestantFor(Map<String, dynamic> finalis) {
    final ext = '${finalis['id_finalis']}';
    final existing = _contestants.where((c) => c.externalId == ext).firstOrNull;
    if (existing != null) return existing;
    final created = ContestantMaster.fromApi(finalis, id: nextContestantId());
    _contestants.add(created);
    return created;
  }

  JudgeMaster _judgeFor(int id, Map<String, dynamic>? raw) {
    final existing = getJudge(id);
    if (existing != null || raw == null) return existing ?? JudgeMaster(id: id, displayNumber: '$id', name: 'Judge $id', email: '', phone: '');
    final next = _judges.fold<int>(0, (m, j) => math.max(m, int.tryParse(j.displayNumber) ?? 0)) + 1;
    final created = JudgeMaster.fromApi(raw, displayNumber: next.toString().padLeft(2, '0'));
    _judges.add(created);
    return created;
  }

  void _applyRound(
    AdminRound round, {
    required List<Map<String, dynamic>> contestants,
    required List<Map<String, dynamic>> judges,
    required List<Map<String, dynamic>> criteria,
    required Map<String, dynamic> monitoring,
    Map<String, dynamic>? results,
    Map<String, dynamic>? advancement,
  }) {
    final id = round.id;
    final i = rounds.indexWhere((r) => r.id == id);
    if (i < 0) {
      rounds.add(round);
    } else {
      rounds[i] = round;
    }
    rounds.sort((a, b) => a.order.compareTo(b.order));
    _visibility[id] = round.resultVisibility;
    if (round.tieAcknowledgedAt != null) _tieAcknowledged[id] = true;

    // Contestants.
    final rc = <int, int>{};
    for (final c in contestants) {
      if ('${c['status'] ?? 'active'}' != 'active' || c['finalis'] is! Map) continue;
      rc[_contestantFor(Map<String, dynamic>.from(c['finalis'] as Map)).id] = _int(c['id']);
    }
    _roundContestantIds[id] = rc;
    _contestantAssignments[id] = rc.keys.toList();

    // Judge assignments.
    _judgeAssignments[id] = [
      for (final a in judges)
        // flag_aktif comes as bool here but as 1/0 on /judges: both mean the same.
        if (a['flag_aktif'] != false && '${a['flag_aktif']}' != '0')
          JudgeAssignment(
            judgeId: _judgeFor(_int(a['judge_id']), a['judge'] is Map ? Map<String, dynamic>.from(a['judge'] as Map) : null).id,
            roundId: id,
            required: a['required'] != false,
            status: switch ('${a['assignment_status'] ?? 'assigned'}') {
              'excused' => 'excused',
              'removed' => 'removed',
              'unassigned' => 'unassigned',
              _ => 'assigned',
            },
            excuseReason: a['excuse_reason'] as String?,
            excusedAt: DateTime.tryParse('${a['status_changed_at']}'),
          ),
    ];

    _keepExcused(id);

    // Criteria (inactive ones are hidden).
    final active = criteria.where((c) => c['flag_aktif'] != false).toList();
    final parentIds = {for (final c in active) if (c['parent_id'] != null) '${c['parent_id']}'};
    _criteriaByRound[id] = [
      for (final (n, c) in active.indexed)
        () {
          final max = _dbl(c['max_points'], 10);
          // A parent group has children — or, before its first child is
          // added, is saved as a top-level non-scored 0% criterion (as the
          // editor sends it), so it can be picked as a Parent right away.
          final isParent = parentIds.contains('${c['id']}') ||
              (c['is_scored'] == false && c['parent_id'] == null && _dbl(c['weight'], 0) == 0);
          return AdminCriterion(
            id: '${c['id']}',
            roundId: id,
            name: '${c['name'] ?? ''}',
            description: '${c['description'] ?? ''}',
            parentId: c['parent_id'] == null ? null : '${c['parent_id']}',
            weight: isParent ? 0 : _dbl(c['weight'], 0),
            minScore: _dbl(c['min_points'], 0),
            maxScore: max,
            step: c['step'] == null ? (max <= 10 ? 0.25 : 1) : _dbl(c['step'], 1),
            isScored: c['is_scored'] != false && !isParent,
            isParent: isParent,
            sequence: n + 1,
          );
        }(),
    ];

    // Monitoring.
    _progress[id] = {
      for (final j in (monitoring['judges'] as List? ?? const []))
        if (j is Map) _int(j['judge_id']): _JudgeProgress.fromApi(Map<String, dynamic>.from(j)),
    };
    _submissionOverrides.remove(id);

    // Results: provisional (closed) or the official snapshot (finalized).
    _provisional.remove(id);
    if (results != null) {
      final result = _resultFromApi(round, results);
      if (round.status == 'finalized') {
        _snapshots[id] = result;
      } else {
        _provisional[id] = result;
      }
    } else if (round.status != 'finalized') {
      _snapshots.remove(id);
    }

    // Advancement from this (finalized) round.
    if (advancement != null) {
      final info = AdvancementInfo.fromApi(
        advancement,
        contestantOf: (rcId) => _contestantForRc(id, rcId),
        contestantOfFinalis: (ext) => _contestants.where((c) => c.externalId == ext).firstOrNull?.id,
      );
      _advancementInfo[id] = info;
      if (info.currentIds.isNotEmpty && info.targetRoundId != null) {
        final last = info.lastConfirmed;
        _advancementBySource[id] = Advancement(
          sourceRoundId: id,
          targetRoundId: info.targetRoundId!,
          selectedContestantIds: info.currentIds,
          snapshotId: '$id',
          method: last?.method == 'manual' ? 'manual' : 'top_n',
          reason: last?.reason ?? '',
          confirmedBy: last?.actor ?? '—',
          confirmedAt: last?.at ?? round.finalizedAt ?? DateTime.now(),
        );
      } else {
        _advancementBySource.remove(id);
      }
    }
    _loadedRounds.add(id);
  }

  int? _contestantForRc(int roundId, int rcId) =>
      _roundContestantIds[roundId]?.entries.where((e) => e.value == rcId).firstOrNull?.key;

  RoundResult _resultFromApi(AdminRound round, Map<String, dynamic> json) {
    final eligible = [
      for (final e in (_progress[round.id] ?? const <int, _JudgeProgress>{}).entries)
        if (e.value.done) e.key,
    ];
    final items = <ResultItem>[];
    for (final raw in (json['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final contestant = item['contestant'] is Map ? Map<String, dynamic>.from(item['contestant'] as Map) : const <String, dynamic>{};
      final master = contestant['finalis'] is Map
          ? _contestantFor(Map<String, dynamic>.from(contestant['finalis'] as Map))
          : getContestant(_contestantForRc(round.id, _int(item['round_contestant_id'])) ?? -1);
      if (master == null) continue;
      items.add(ResultItem(
        contestantId: master.id,
        number: master.number,
        name: master.name,
        profesi: master.profesi,
        photo: master.photo,
        combinedScore: _dbl(item['avg_score'], 0),
        eligibleJudgeCount: eligible.length,
        judgeScores: [],
        rank: _int(item['rank_no']),
      ));
    }
    items.sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : a.number.compareTo(b.number));
    for (final item in items) {
      item.tied = items.where((o) => o.combinedScore == item.combinedScore).length > 1;
    }
    return RoundResult(
      roundId: round.id,
      eligibleJudgeIds: eligible,
      contestantCount: items.length,
      items: items,
      finalized: json['is_final'] == true || round.status == 'finalized',
      finalizedAt: DateTime.tryParse('${json['computed_at']}') ?? round.finalizedAt,
      finalizedBy: null,
    );
  }

  /// Fills a result row's per-judge scores from `GET rounds/{id}/results/{rc}`.
  Future<String?> loadResultDetail(int roundId, int contestantId) async {
    final api = _api;
    final rc = _roundContestantIds[roundId]?[contestantId];
    if (api == null || rc == null) return null;
    try {
      final data = await api.resultDetail(roundId, rc);
      final result = _snapshots[roundId] ?? _provisional[roundId];
      final item = result?.items.where((i) => i.contestantId == contestantId).firstOrNull;
      if (item == null) return null;
      item.judgeScores
        ..clear()
        ..addAll([
          for (final raw in (data['per_juri'] as List? ?? const []))
            if (raw is Map)
              () {
                final j = Map<String, dynamic>.from(raw);
                final judge = _judgeFor(_int(j['judge_id']), j['judge'] is Map ? Map<String, dynamic>.from(j['judge'] as Map) : null);
                final scores = [for (final s in (j['scores'] as List? ?? const [])) if (s is Map) s];
                final submitted = ['submitted', 'resubmitted', 'locked'].contains(j['status']);
                return JudgeScoreEntry(
                  judgeId: judge.id,
                  judgeNumber: judge.label,
                  judgeName: judge.name,
                  total: scores.isEmpty ? null : scores.fold<double>(0, (t, s) => t + _dbl(s['total_score'], 0)),
                  included: submitted,
                  exclusion: submitted ? '' : 'Not Submitted — Not Counted',
                  criteriaScores: {
                    for (final s in scores)
                      if (s['raw_score'] != null) '${s['round_criteria_id']}': _dbl(s['raw_score'], 0),
                  },
                );
              }(),
        ]);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// A judge's scores for one contestant, once [loadResultDetail] ran.
  JudgeScoreEntry? judgeScoreEntry(int roundId, int judgeId, int contestantId) =>
      (_snapshots[roundId] ?? _provisional[roundId])
          ?.items
          .where((i) => i.contestantId == contestantId)
          .firstOrNull
          ?.judgeScores
          .where((j) => j.judgeId == judgeId)
          .firstOrNull;

  // ------------------------------------------------------ round actions (API)

  /// Runs an Admin API command, then reloads the round (and the event's round
  /// list when [event] is set). Returns an error message, or null.
  Future<String?> _remote(Future<void> Function(AdminApi api) command, {int? roundId, bool reloadEvent = false}) async {
    try {
      await command(_api!);
    } on ApiException catch (e) {
      return e.fieldErrors.values.expand((m) => m).firstOrNull ?? e.message;
    }
    if (reloadEvent) {
      final error = await refreshEvent();
      if (error != null) return error;
    } else if (roundId != null) {
      final error = await loadRound(roundId);
      if (error != null) return error;
    }
    return null;
  }

  static const _notConnected = 'This action is not connected to the Admin API yet.';

  Future<String?> openRoundAction(int id) async =>
      connected ? _remote((a) => a.openRound(id), roundId: id) : (openRound(id) ? null : 'The round is not ready to open.');

  Future<String?> closeRoundAction(int id) async => connected
      ? _remote((a) => a.closeRound(id), roundId: id)
      : (closeRound(id) ? null : 'This action is not available now. Refresh and check round readiness.');

  Future<String?> finalizeAction(int id) async => connected
      ? _remote((a) => a.finalizeRound(id), reloadEvent: true)
      : (finalizeResults(id) ? null : 'Results cannot be finalized yet. Check ties and required submissions.');

  Future<String?> setResultVisibilityAction(int id, bool visible) async => connected
      ? _remote((a) => a.setResultVisibility(id, visible), roundId: id)
      : (setResultVisibility(id, visible) ? null : 'Visibility can change only after finalization.');

  Future<String?> updateRoundAction(int id,
          {required String name, required String promoteMode, required int promoteTopN, required bool favoritPromoteEnabled}) async =>
      connected
          ? _remote(
              (a) => a.updateRound(id,
                  name: name, promoteMode: promoteMode, promoteTopN: promoteTopN, favoritPromoteEnabled: favoritPromoteEnabled),
              reloadEvent: true)
          : _notConnected;

  /// Only the API call: the caller leaves the round's pages, then reloads
  /// the event ([refreshEvent]) so no open page loses its round.
  Future<String?> deleteRoundAction(int id) async => connected ? _remote((a) => a.deleteRound(id)) : _notConnected;

  /// Round contestant roster: adds/removes the difference.
  Future<String?> setRoundContestantsAction(int roundId, List<int> ids) async {
    if (!connected) return setRoundContestantAssignments(roundId, ids) ? null : 'Contestants can change only while the round is Draft.';
    final current = _roundContestantIds[roundId] ?? const <int, int>{};
    return _remote((a) async {
      for (final id in ids.where((id) => !current.containsKey(id))) {
        final ext = getContestant(id)?.externalId;
        if (ext != null) await a.addRoundContestant(roundId, ext);
      }
      for (final e in current.entries.where((e) => !ids.contains(e.key))) {
        await a.removeRoundContestant(roundId, e.value);
      }
    }, roundId: roundId);
  }

  Future<String?> setJudgeAssignmentAction(int roundId, int judgeId, bool enabled) async {
    if (!connected) {
      setJudgeAssignment(roundId, judgeId, enabled);
      return null;
    }
    return _remote(
        (a) => enabled
            ? a.addRoundJudge(roundId, judgeId, required: eventSettings.defaultJudgeAssignmentRequired)
            : a.removeRoundJudge(roundId, judgeId),
        roundId: roundId);
  }

  /// Unchecking Required = `required: false` on the assignment
  /// (`PATCH judges/{judgeId}`). The reloaded assignment is checked: a server
  /// that ignores `required` gets reported, never silently kept.
  Future<String?> setJudgeRequiredAction(int roundId, int judgeId, bool required) async {
    if (!connected) {
      setJudgeRequired(roundId, judgeId, required);
      return null;
    }
    if (getRound(roundId)?.status != 'draft') return 'Required can change only while the round is Draft.';
    final error = await _remote((a) => a.updateRoundJudge(roundId, judgeId, required: required), roundId: roundId);
    if (error != null) return error;
    final saved = (_judgeAssignments[roundId] ?? const <JudgeAssignment>[]).where((a) => a.judgeId == judgeId).firstOrNull;
    if (saved == null) return 'The judge is no longer assigned to this round.';
    if (saved.required != required) return 'The server did not save ${required ? 'Required' : 'Optional'} for this judge yet.';
    return null;
  }

  /// [parentId] is the parent's *server* id (null = top level). `step` is
  /// sent only when it differs from [unchangedStep] (the value the admin
  /// started from), so an untouched form default never changes a scale
  /// (no step on the server = 0.25 up to 10 points, else 1).
  static Map<String, dynamic> _criterionBody(AdminCriterion c, {int? parentId, double? unchangedStep, bool update = false}) => {
        'name': c.name,
        'description': c.description,
        'min_points': c.minScore,
        'max_points': c.maxScore,
        'weight': c.isParent ? 0 : c.weight,
        'is_scored': c.isScored && !c.isParent,
        // Numeric only ("step: numeric, minimal 0" — no null).
        if (c.step != unchangedStep) 'step': c.step,
        'parent_id': c.isParent ? null : parentId,
        if (update) 'flag_aktif': true,
      };

  /// Creates [list] in [roundId], parents first, so children can point at
  /// their parent's new server id. [remoteIds] maps local → server ids and
  /// is filled with the created ones.
  static Future<void> _createCriteria(AdminApi a, int roundId, Iterable<AdminCriterion> list, Map<String, int> remoteIds,
      {double? unchangedStep}) async {
    for (final c in [...list.where((c) => c.isParent), ...list.where((c) => !c.isParent)]) {
      final created =
          await a.createCriterion(roundId, _criterionBody(c, parentId: remoteIds[c.parentId], unchangedStep: unchangedStep));
      if (created != null) remoteIds[c.id] = created;
    }
  }

  /// Criteria editor save: the whole list, as in the prototype; with the API
  /// the difference is sent as create / update / delete.
  Future<String?> saveCriteriaAction(int roundId, List<AdminCriterion> list) async {
    if (!connected) return setCriteria(roundId, list) ? null : 'Criteria can change only while the round is Draft.';
    final before = {for (final c in _criteriaByRound[roundId] ?? const <AdminCriterion>[]) c.id: c};
    return _remote((a) async {
      final remoteIds = {for (final id in before.keys) if (int.tryParse(id) != null) id: int.parse(id)};
      bool isNew(AdminCriterion c) => before[c.id] == null || int.tryParse(c.id) == null;
      await _createCriteria(a, roundId, list.where(isNew), remoteIds, unchangedStep: eventSettings.step);
      // Sub-criteria first: a parent that still has children is forced to
      // non-scored 0% by the server, so detach/attach them before it changes.
      // (ordered by what each one was on the server before this save).
      bool wasParent(AdminCriterion c) => before[c.id]!.isParent;
      for (final c in [
        ...list.where((c) => !isNew(c) && !wasParent(c)),
        ...list.where((c) => !isNew(c) && wasParent(c)),
      ]) {
        final old = before[c.id]!;
        if (jsonEncode(old.toJson()) != jsonEncode(c.toJson())) {
          await a.updateCriterion(
              roundId, remoteIds[c.id]!, _criterionBody(c, parentId: remoteIds[c.parentId], unchangedStep: old.step, update: true));
        }
      }
      // Children before parents, so no parent is deleted while still in use.
      final removed = before.values.where((c) => !list.any((n) => n.id == c.id)).toList()
        ..sort((x, y) => (x.isParent ? 1 : 0).compareTo(y.isParent ? 1 : 0));
      for (final c in removed) {
        final remoteId = int.tryParse(c.id);
        if (remoteId != null) await a.deleteCriterion(roundId, remoteId);
      }
    }, roundId: roundId);
  }

  Future<String?> deleteCriterionAction(int roundId, String criterionId) async {
    if (!connected) {
      return setCriteria(roundId, getCriteria(roundId)..removeWhere((c) => c.id == criterionId))
          ? null
          : 'Criteria can change only while the round is Draft.';
    }
    final remoteId = int.tryParse(criterionId);
    if (remoteId == null) return _notConnected;
    return _remote((a) => a.deleteCriterion(roundId, remoteId), roundId: roundId);
  }

  /// Reopen = every submitted sheet of the judge in this round.
  Future<String?> reopenAction(int roundId, int judgeId, String reason) async {
    if (!connected) {
      final r = reopen(roundId, judgeId, reason);
      return r.ok ? null : r.message;
    }
    if (reason.trim().isEmpty) return 'A reason is required.';
    final sheets = _progress[roundId]?[judgeId]?.submittedSheetIds ?? const <int>[];
    if (sheets.isEmpty) return 'This judge has no submitted score sheets to reopen.';
    return _remote((a) async {
      for (final sheet in sheets) {
        await a.reopenScoreSheet(roundId, sheet, reason.trim());
      }
    }, roundId: roundId);
  }

  /// Judges excused from this device. `GET rounds/{id}/judges` leaves
  /// excused judges out, so they are kept here to stay visible (Monitoring)
  /// and restorable until the server lists them again.
  final Map<int, Map<int, JudgeAssignment>> _excusedKept = {};

  /// excuse / restore = `PATCH judges/{judgeId}` assignment_status
  /// (excused + excuse_reason / assigned); remove = unassign (DELETE).
  Future<String?> judgeGovernanceAction(int roundId, int judgeId, String action, String reason) async {
    if (!connected) {
      final r = updateJudgeAssignment(roundId, judgeId, action, reason);
      return r.ok ? null : r.message;
    }
    final why = reason.trim();
    switch (action) {
      case 'excuse':
        if (why.isEmpty) return 'A reason is required.';
        final before = (_judgeAssignments[roundId] ?? const <JudgeAssignment>[]).where((a) => a.judgeId == judgeId).firstOrNull;
        final error = await _remote(
            (a) => a.updateRoundJudge(roundId, judgeId, status: 'excused', excuseReason: why), roundId: roundId);
        if (error != null) return error;
        _excusedKept.putIfAbsent(roundId, () => {})[judgeId] = JudgeAssignment(
          judgeId: judgeId,
          roundId: roundId,
          required: before?.required ?? true,
          status: 'excused',
          excuseReason: why,
          excusedAt: DateTime.now(),
        );
        _keepExcused(roundId);
        _save();
        return null;
      case 'restore':
        final error = await _remote((a) => a.updateRoundJudge(roundId, judgeId, status: 'assigned'), roundId: roundId);
        if (error == null) {
          _excusedKept[roundId]?.remove(judgeId);
          await loadRound(roundId);
        }
        return error;
      case 'remove':
        _excusedKept[roundId]?.remove(judgeId);
        return _remote((a) => a.removeRoundJudge(roundId, judgeId), roundId: roundId);
    }
    return _notConnected;
  }

  /// Re-adds the device-kept excused judges the server no longer lists.
  void _keepExcused(int roundId) {
    final kept = _excusedKept[roundId];
    if (kept == null || kept.isEmpty) return;
    final list = _judgeAssignments.putIfAbsent(roundId, () => []);
    kept.removeWhere((id, _) => list.any((a) => a.judgeId == id && a.status != 'excused')); // back on the server
    for (final a in kept.values) {
      list.removeWhere((x) => x.judgeId == a.judgeId);
      list.add(a);
    }
  }

  /// Copies judges and/or criteria from [sourceId] into the draft target
  /// with the assignment / criteria endpoints.
  Future<String?> copyConfigurationAction(int sourceId, int targetId, {required bool judges, required bool criteria}) async {
    if (!connected) {
      return copyRoundConfiguration(sourceId, targetId, judges: judges, criteria: criteria)
          ? null
          : 'Copy is available only into the next Draft round.';
    }
    // Inactive master judges are not copied into the new round.
    final judgeIds = [for (final (a, j) in getRoundJudges(sourceId)) if (a.status == 'assigned' && j.active) a.judgeId];
    final requiredOf = {for (final (a, _) in getRoundJudges(sourceId)) a.judgeId: a.required};
    final existingJudges = {for (final (a, _) in getRoundJudges(targetId)) if (a.status == 'assigned') a.judgeId};
    final source = getCriteria(sourceId);
    final existingCriteria = getCriteria(targetId);
    return _remote((a) async {
      if (judges) {
        for (final id in judgeIds.where((id) => !existingJudges.contains(id))) {
          await a.addRoundJudge(targetId, id, required: requiredOf[id] ?? true);
        }
      }
      if (criteria) {
        // Copy replaces the target's criteria (as offline): appending would
        // double the weight (e.g. 200%) and block Open Round.
        for (final c in existingCriteria.where((c) => !c.isParent).followedBy(existingCriteria.where((c) => c.isParent))) {
          final remoteId = int.tryParse(c.id);
          if (remoteId != null) await a.deleteCriterion(targetId, remoteId);
        }
        await _createCriteria(a, targetId, source, {});
      }
    }, roundId: targetId);
  }

  /// Source rounds whose advancement confirm request is in flight.
  final Set<int> _confirmingAdvancement = {};

  /// True while a confirm is being sent, or once this round's advancement is
  /// confirmed (locally or per the server history) — until it is reset. The
  /// server still answers `can_confirm: true` after a confirmation, so this
  /// is what stops a second (duplicate) confirmation.
  bool isAdvancementConfirmed(int roundId) =>
      _confirmingAdvancement.contains(roundId) ||
      getAdvancement(roundId) != null ||
      (_advancementInfo[roundId]?.confirmed ?? false);

  /// `POST rounds/{id}/advancement` with the source round's
  /// round_contestant ids; reloads the event (target roster changes).
  Future<String?> confirmAdvancementAction(int roundId, List<int> ids, String reason, {bool includeFavorit = false}) async {
    if (!connected) {
      final r = confirmAdvancement(roundId, ids, reason);
      return r.ok ? null : r.message;
    }
    if (isAdvancementConfirmed(roundId)) return 'Advancement for this round is already confirmed.';
    final check = validateAdvancement(roundId, ids, reason);
    if (!check.ok) return check.message;
    final rc = _roundContestantIds[roundId] ?? const <int, int>{};
    final rcIds = [for (final id in ids) ?rc[id]];
    if (rcIds.length != ids.length) return 'Some selected contestants are not in this round any more. Reload and try again.';
    _confirmingAdvancement.add(roundId);
    try {
      return await _remote(
        (a) => a.confirmAdvancement(roundId, roundContestantIds: rcIds, reason: reason.trim(), includeFavorit: includeFavorit),
        reloadEvent: true,
      );
    } finally {
      _confirmingAdvancement.remove(roundId);
    }
  }

  /// `DELETE rounds/{id}/advancement?reason=` (reason 3–1000 characters).
  Future<String?> resetAdvancementAction(int roundId, String reason) async {
    if (!connected) {
      return resetAdvancement(roundId, reason) ? null : 'Advancement can only be reset while the next round is Draft.';
    }
    final r = reason.trim();
    if (r.length < 3) return 'The reason must be at least 3 characters.';
    return _remote((a) => a.resetAdvancement(roundId, r.length > 1000 ? r.substring(0, 1000) : r), reloadEvent: true);
  }

  /// Withdrawal/replacement on an advanced Draft target. With the API there is
  /// no adjustment endpoint: the roster difference is sent (reason not stored).
  Future<String?> adjustAdvancementAction(int targetRoundId, List<int> ids, String reason) async {
    if (!connected) {
      return adjustAdvancementAssignment(targetRoundId, ids, reason) ? null : 'This adjustment is not available now.';
    }
    return setRoundContestantsAction(targetRoundId, ids);
  }

  /// The API judge list replaces the local one; the app-only display number
  /// is kept per judge id, new judges get the next number.
  void _mergeJudges(List<Map<String, dynamic>> raw) {
    final numbers = {for (final j in _judges) j.id: j.displayNumber};
    var next = _judges.fold<int>(0, (m, j) => math.max(m, int.tryParse(j.displayNumber) ?? 0)) + 1;
    final sorted = [...raw]..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    _judges = [
      for (final j in sorted)
        JudgeMaster.fromApi(
          j,
          displayNumber: numbers[int.tryParse('${j['id']}')] ?? (next++).toString().padLeft(2, '0'),
        ),
    ];
  }

  Future<String?> _reloadJudges() async {
    try {
      _lastJudges = await _api!.judges();
      _mergeJudges(_lastJudges);
      _save();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  static AdminActionResult _fail(ApiException e) =>
      AdminActionResult.fail(e.fieldErrors.values.expand((m) => m).firstOrNull ?? e.message);

  /// Judge master create (`POST`, [password] required) or update (`PATCH`,
  /// empty [password] = unchanged), then reloads the list. Without the API
  /// the change is stored locally, like the prototype.
  Future<AdminActionResult> submitJudge(JudgeMaster item, {required bool isNew, String password = ''}) async {
    final api = _api;
    if (api == null) {
      saveJudge(item);
      return const AdminActionResult.ok();
    }
    try {
      if (isNew) {
        await api.createJudge(
            name: item.name, email: item.email, password: password, phone: item.phone, active: item.active);
      } else {
        await api.updateJudge(item.id,
            name: item.name, email: item.email, password: password, phone: item.phone, active: item.active);
      }
    } on ApiException catch (e) {
      return _fail(e);
    }
    final existing = getJudge(item.id);
    if (existing != null) existing.displayNumber = item.displayNumber; // app-only field
    final error = await _reloadJudges();
    return error == null ? const AdminActionResult.ok() : AdminActionResult.fail(error);
  }

  /// `DELETE /judge/admin/judges/{id}`.
  Future<AdminActionResult> deleteJudge(int id) async {
    final api = _api;
    if (api == null) return const AdminActionResult.fail('Deleting judges is not available in this prototype.');
    try {
      await api.deleteJudge(id);
    } on ApiException catch (e) {
      return _fail(e);
    }
    final error = await _reloadJudges();
    return error == null ? const AdminActionResult.ok() : AdminActionResult.fail(error);
  }

  /// `PUT /judge/admin/judges/{id}/roles` (no screen uses it yet — the valid
  /// roles/scopes are still to be agreed with the backend).
  Future<AdminActionResult> setJudgeRoles(int id, List<(String, String?)> roles) async {
    final api = _api;
    if (api == null) return const AdminActionResult.fail('Roles are not available in this prototype.');
    try {
      await api.setJudgeRoles(id, roles);
    } on ApiException catch (e) {
      return _fail(e);
    }
    final error = await _reloadJudges();
    return error == null ? const AdminActionResult.ok() : AdminActionResult.fail(error);
  }

  /// API rounds replace the local ones (status, order, promotion, published
  /// results). Placeholder round data sized by the round's counts is only a
  /// fallback until [loadRound] replaces it with the API data.
  void _applyRounds(List<AdminRound> apiRounds) {
    rounds = [...apiRounds]..sort((a, b) => a.order.compareTo(b.order));
    final byNumber = _contestants.where((c) => c.active).toList();
    for (final r in rounds) {
      _contestantAssignments.putIfAbsent(r.id, () => [for (final c in byNumber.take(r.contestantsCount ?? 0)) c.id]);
      _judgeAssignments.putIfAbsent(
        r.id,
        () => [for (final j in _judges.take(r.judgesCount ?? 0)) JudgeAssignment(judgeId: j.id, roundId: r.id)],
      );
      _criteriaByRound.putIfAbsent(r.id, () => _placeholderCriteria(r.id, r.criteriaCount ?? 0));
      _visibility[r.id] = r.resultVisibility;
    }
  }

  static const _placeholderCriteriaNames = [
    'Interview', 'Stage Presence', 'Evening Gown', 'Talent', 'Final Question', 'Overall Impression',
    'Communication', 'Confidence',
  ];

  /// [count] scored criteria with whole-number weights that add up to 100.
  List<AdminCriterion> _placeholderCriteria(int roundId, int count) => [
        for (var i = 0; i < count; i++)
          AdminCriterion(
            id: 'c${i + 1}',
            roundId: roundId,
            name: i < _placeholderCriteriaNames.length ? _placeholderCriteriaNames[i] : 'Criterion ${i + 1}',
            weight: (100 ~/ count + (i == count - 1 ? 100 % count : 0)).toDouble(),
            minScore: eventSettings.minScore,
            maxScore: eventSettings.maxScore,
            step: eventSettings.step,
            sequence: i + 1,
          ),
      ];

  // ----------------------------------------------------------------- seed

  static const _seedContestants = [
    ('Mrs Shaida', 'Malaysia'), ('Mrs Beathres', 'Borneo Island, Malaysia'), ('Mrs Baimar', 'Russia'),
    ('Miss Evgeniya', 'Russia'), ('Miss Nicole', 'Malaysia'), ('Miss Yuka', 'Japan'), ('Miss Park Jinah', 'Korea'),
    ('Miss Lee Seoyul', 'Korea'), ('Miss Veronika', 'Borneo Island, Indonesia'), ('Miss Bolormaa', 'Mongolia'),
    ('Mister Hady', 'Borneo Island, Indonesia'), ('Mister Nicholas', 'Malaysia'), ('Mister Azriq', 'Borneo Island, Brunei'),
    ('Mrs Edelisa', 'Portugal'), ('Mister Jerome', 'Philippines'),
  ];

  static String seedPhoto(int id) => 'assets/admin/contestant-${id.toString().padLeft(2, '0')}.jpg';

  /// Monitoring source for Round 1 (admin-data.js `judgesByRound`).
  static const _round1Activity = <int, (int, String, String, String)>{
    1: (15, 'submitted', 'online', '21:41'),
    2: (15, 'submitted', 'syncing', '21:40'),
    3: (15, 'submitted', 'online', '21:39'),
    4: (12, 'in-progress', 'offline', '21:34'),
    5: (0, 'not-started', 'online', '21:28'),
    6: (15, 'submitted', 'online', '21:37'),
    7: (15, 'submitted', 'online', '21:36'),
  };

  static List<AdminCriterion> _seedCriteria(int roundId) {
    AdminCriterion c(String id, String name, double weight, int seq, {String? parent, bool isParent = false}) =>
        AdminCriterion(
          id: id,
          roundId: roundId,
          name: name,
          weight: weight,
          sequence: seq,
          parentId: parent,
          isParent: isParent,
          isScored: !isParent,
        );
    if (roundId == 1) {
      return [
        c('interview', 'Interview', 0, 1, isParent: true),
        c('communication', 'Communication', 10, 2, parent: 'interview'),
        c('confidence', 'Confidence', 10, 3, parent: 'interview'),
        c('substance', 'Substance', 10, 4, parent: 'interview'),
        c('evening-gown', 'Evening Gown', 30, 5),
        c('stage-presence', 'Stage Presence', 40, 6),
      ];
    }
    if (roundId == 2) {
      return [c('interview', 'Interview', 30, 1), c('stage-presence', 'Stage Presence', 30, 2), c('evening-gown', 'Evening Gown', 40, 3)];
    }
    return [c('final-question', 'Final Question', 40, 1), c('overall-impression', 'Overall Impression', 60, 2)];
  }

  void _seed() {
    rounds = [
      AdminRound(id: 1, order: 1, name: 'Preliminary', status: 'open', advancementCount: 10),
      AdminRound(id: 2, order: 2, name: 'Top 10', status: 'draft', advancementCount: 5),
      AdminRound(id: 3, order: 3, name: 'Final', status: 'draft'),
    ];
    _contestants = [
      for (var i = 0; i < _seedContestants.length; i++)
        ContestantMaster(
          id: i + 1,
          number: i + 1,
          name: _seedContestants[i].$1,
          profesi: _seedContestants[i].$2,
          photo: seedPhoto(i + 1),
        ),
    ];
    _judges = [
      for (final (id, name) in [
        (1, 'Ratih Pramesti'), (2, 'Dimas Ardiansyah'), (3, 'Amanda Wijaya'), (4, 'Budi Santoso'),
        (5, 'Maria Tan'), (6, 'Kevin Mahendra'), (7, 'Sari Handayani'),
      ])
        JudgeMaster(
          id: id,
          displayNumber: id.toString().padLeft(2, '0'),
          name: name,
          email: '${name.split(' ').first.toLowerCase()}@example.test',
          phone: '+62 811 000$id',
        ),
    ];
    _contestantAssignments = {1: [for (final c in _contestants) c.id], 2: [], 3: []};
    _judgeAssignments = {
      for (final r in [1, 2, 3]) r: [for (final j in _judges) JudgeAssignment(judgeId: j.id, roundId: r)],
    };
    _criteriaByRound = {for (final r in [1, 2, 3]) r: _seedCriteria(r)};
    _reopensByRound = {};
    _submissionOverrides = {};
    _auditEvents = [];
    _snapshots = {};
    _visibility = {};
    _tieAcknowledged = {};
    _advancementBySource = {};
    _advancementHistory = [];
    eventSettings = const EventSettings();
  }

  // ---------------------------------------------------------- persistence

  static Map<int, T> _intMap<T>(Object? raw, T Function(Object? v) f) => {
        if (raw is Map)
          for (final e in raw.entries)
            if (int.tryParse('${e.key}') != null) int.parse('${e.key}'): f(e.value),
      };

  void _restore(Map<String, dynamic> j) {
    final statuses = _intMap(j['roundStatusById'], (v) => '$v');
    for (final r in rounds) {
      r.status = statuses[r.id] ?? r.status;
    }
    if (j['contestants'] is List) {
      _contestants = [for (final c in j['contestants'] as List) ContestantMaster.fromJson(Map<String, dynamic>.from(c as Map))];
    }
    if (j['judges'] is List) {
      _judges = [for (final c in j['judges'] as List) JudgeMaster.fromJson(Map<String, dynamic>.from(c as Map))];
    }
    if (j['contestantAssignments'] is Map) {
      _contestantAssignments = _intMap(j['contestantAssignments'], (v) => [for (final i in v as List) (i as num).toInt()]);
    }
    if (j['judgeAssignments'] is Map) {
      _judgeAssignments = _intMap(
        j['judgeAssignments'],
        (v) => [for (final a in v as List) JudgeAssignment.fromJson(Map<String, dynamic>.from(a as Map))],
      );
    }
    if (j['criteriaByRound'] is Map) {
      _criteriaByRound = _intMap(
        j['criteriaByRound'],
        (v) => [for (final a in v as List) AdminCriterion.fromJson(Map<String, dynamic>.from(a as Map))],
      );
    }
    _reopensByRound = _intMap(
      j['reopensByRound'],
      (v) => [for (final a in v as List) ReopenRecord.fromJson(Map<String, dynamic>.from(a as Map))],
    );
    _submissionOverrides = _intMap(
      j['submissionOverridesByRound'],
      (v) => _intMap(v, (o) {
        final m = Map<String, dynamic>.from(o as Map);
        return (status: '${m['status']}', submittedAt: DateTime.tryParse('${m['submittedAt']}'));
      }),
    );
    _auditEvents = [
      for (final a in (j['auditEvents'] as List? ?? const [])) AuditEvent.fromJson(Map<String, dynamic>.from(a as Map)),
    ];
    _snapshots = _intMap(j['resultSnapshotByRound'], (v) => RoundResult.snapshotFromJson(Map<String, dynamic>.from(v as Map)));
    _visibility = _intMap(j['resultVisibilityByRound'], (v) => v == true);
    _tieAcknowledged = _intMap(j['tieAcknowledgementByRound'], (v) => v == true);
    _advancementBySource =
        _intMap(j['advancementBySource'], (v) => Advancement.fromJson(Map<String, dynamic>.from(v as Map)));
    _advancementHistory = [
      for (final h in (j['advancementHistory'] as List? ?? const [])) Map<String, dynamic>.from(h as Map),
    ];
    if (j['eventSettings'] is Map) {
      eventSettings = EventSettings.fromJson(Map<String, dynamic>.from(j['eventSettings'] as Map));
    }
  }

  Map<String, dynamic> _toJson() => {
        'schemaVersion': schemaVersion,
        'roundStatusById': {for (final r in rounds) '${r.id}': r.status},
        'contestants': [for (final c in _contestants) c.toJson()],
        'judges': [for (final c in _judges) c.toJson()],
        'contestantAssignments': {for (final e in _contestantAssignments.entries) '${e.key}': e.value},
        'judgeAssignments': {
          for (final e in _judgeAssignments.entries) '${e.key}': [for (final a in e.value) a.toJson()],
        },
        'criteriaByRound': {
          for (final e in _criteriaByRound.entries) '${e.key}': [for (final a in e.value) a.toJson()],
        },
        'reopensByRound': {
          for (final e in _reopensByRound.entries) '${e.key}': [for (final a in e.value) a.toJson()],
        },
        'submissionOverridesByRound': {
          for (final e in _submissionOverrides.entries)
            '${e.key}': {
              for (final o in e.value.entries)
                '${o.key}': {'status': o.value.status, 'submittedAt': o.value.submittedAt?.toIso8601String()},
            },
        },
        'auditEvents': [for (final a in _auditEvents) a.toJson()],
        'resultSnapshotByRound': {for (final e in _snapshots.entries) '${e.key}': e.value.toJson()},
        'resultVisibilityByRound': {for (final e in _visibility.entries) '${e.key}': e.value},
        'tieAcknowledgementByRound': {for (final e in _tieAcknowledged.entries) '${e.key}': e.value},
        'advancementBySource': {for (final e in _advancementBySource.entries) '${e.key}': e.value.toJson()},
        'advancementHistory': _advancementHistory,
        'eventSettings': eventSettings.toJson(),
      };

  bool _save() {
    notifyListeners();
    if (needsEvent) return true;
    try {
      _prefs?.setString(_storageKey, jsonEncode(_toJson()));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Dev: restore the prototype seed.
  void resetAll() {
    if (connected) {
      final detail = _lastDetail;
      if (detail == null) return;
      _prefs?.remove(_storageKey);
      event = null;
      _applyEvent(detail, _lastContestants, _lastJudges);
      return;
    }
    _seed();
    _save();
  }

  // -------------------------------------------------------------- queries

  AdminRound? getRound(int id) => rounds.where((r) => r.id == id).firstOrNull;

  List<AdminRound> get orderedRounds => [...rounds]..sort((a, b) => a.order.compareTo(b.order));

  AdminRound? getNextRound(int roundId) {
    final round = getRound(roundId);
    if (round == null) return null;
    return orderedRounds.where((r) => r.order > round.order).firstOrNull;
  }

  AdminRound? getPreviousRound(int roundId) {
    final round = getRound(roundId);
    if (round == null) return null;
    return orderedRounds.reversed.where((r) => r.order < round.order).firstOrNull;
  }

  /// The round the event is currently working on (Overview "Current stage").
  /// Null when the event has no rounds yet.
  AdminRound? get activeRound =>
      rounds.where((r) => r.status == 'open').firstOrNull ??
      rounds.where((r) => r.status == 'draft' && getAdvancementForTarget(r.id) != null).firstOrNull ??
      rounds.where((r) => r.status != 'finalized').firstOrNull ??
      rounds.lastOrNull;

  List<ContestantMaster> get contestants => List.unmodifiable(_contestants);
  List<JudgeMaster> get judges => List.unmodifiable(_judges);
  ContestantMaster? getContestant(int id) => _contestants.where((c) => c.id == id).firstOrNull;
  JudgeMaster? getJudge(int id) => _judges.where((j) => j.id == id).firstOrNull;

  List<ContestantMaster> getRoundContestants(int roundId) {
    final ids = _contestantAssignments[roundId] ?? const [];
    return _contestants.where((c) => ids.contains(c.id)).toList();
  }

  List<(JudgeAssignment, JudgeMaster)> getRoundJudges(int roundId) => [
        for (final a in _judgeAssignments[roundId] ?? const <JudgeAssignment>[])
          if (getJudge(a.judgeId) != null) (a, getJudge(a.judgeId)!),
      ];

  List<String> roundsForContestant(int id) =>
      [for (final r in orderedRounds) if (getRoundContestants(r.id).any((c) => c.id == id)) r.name];

  List<String> roundsForJudge(int id) => [
        for (final r in orderedRounds)
          if (getRoundJudges(r.id).any((e) => e.$1.judgeId == id && e.$1.status == 'assigned')) r.name,
      ];

  List<AdminCriterion> getCriteria(int roundId) => [for (final c in _criteriaByRound[roundId] ?? const []) c.copy()];

  /// Sole effective-weight calculation: only scored, non-parent criteria count.
  static double effectiveScoredWeight(List<AdminCriterion> criteria) =>
      criteria.where((c) => c.isScored && !c.isParent).fold(0, (s, c) => s + c.weight);

  List<MonitoringJudge> getMonitoringJudges(int roundId) {
    final round = getRound(roundId);
    final contestantCount = getRoundContestants(roundId).length;
    return [
      for (final (assignment, judge) in getRoundJudges(roundId))
        () {
          final live = _progress[roundId];
          if (live != null) {
            final p = live[judge.id];
            final status = assignment.status == 'excused' || assignment.status == 'removed'
                ? assignment.status
                : p?.status ?? 'not-started';
            return MonitoringJudge(
              id: judge.id,
              number: judge.label,
              name: judge.name,
              email: judge.email,
              phone: judge.phone,
              completed: p?.sheets ?? 0,
              total: contestantCount,
              submissionStatus: status,
              connection: 'online', // devices API not available yet
              lastSync: '—',
              required: assignment.required,
              assignmentStatus: assignment.status,
              submittedAt: p?.submittedAt,
            );
          }
          (int, String, String, String)? source = roundId == 1 ? _round1Activity[judge.id] : null;
          if (source == null && round != null && round.status != 'draft') {
            // A closed/finalized round only got there with every sheet in.
            final demoSubmitted = round.status != 'open' || [1, 2, 6, 7].contains(judge.id);
            source = demoSubmitted
                ? (contestantCount, 'submitted', 'online', '—')
                : judge.id == 4
                    ? (math.max(0, contestantCount - 3), 'in-progress', 'online', '—')
                    : (0, 'not-started', 'online', '—');
          }
          final override = _submissionOverrides[roundId]?[judge.id];
          var status = source?.$2 ?? 'not-started';
          if (override != null) status = override.status;
          if (assignment.status == 'excused' || assignment.status == 'removed') status = assignment.status;
          return MonitoringJudge(
            id: judge.id,
            number: judge.label,
            name: judge.name,
            email: judge.email,
            phone: judge.phone,
            completed: source?.$1 ?? 0,
            total: contestantCount,
            submissionStatus: status,
            connection: source?.$3 ?? 'online',
            lastSync: source?.$4 ?? '—',
            required: assignment.required,
            assignmentStatus: assignment.status,
            submittedAt: override?.submittedAt ?? (source?.$2 == 'submitted' ? DateTime(2026, 9, 23, 21, 42) : null),
          );
        }(),
    ];
  }

  Readiness getRoundReadiness(int roundId) {
    final round = getRound(roundId)!;
    final contestants = getRoundContestants(roundId);
    final assignments = getRoundJudges(roundId).where((e) => e.$1.status == 'assigned').toList();
    final required = assignments.where((e) => e.$1.required).toList();
    final activity = getMonitoringJudges(roundId);
    String statusOf(int id) => activity.where((a) => a.id == id).firstOrNull?.submissionStatus ?? 'not-started';
    bool done(String s) => s == 'submitted' || s == 'resubmitted';
    final rows = [for (final a in assignments) statusOf(a.$1.judgeId)];
    final summary = SubmissionSummary(
      rows.length,
      rows.where(done).length,
      rows.where((s) => s == 'in-progress' || s == 'reopened').length,
      rows.where((s) => s == 'not-started').length,
    );
    final requiredSubmitted = required.where((e) => done(statusOf(e.$1.judgeId))).length;
    final criteria = getCriteria(roundId);
    final weight = effectiveScoredWeight(criteria);
    final weightValid = weight == 100;
    final criteriaValid = criteria.any((c) => c.isScored && !c.isParent) &&
        criteria.every((c) =>
            !c.isScored ||
            c.isParent ||
            (c.name.trim().isNotEmpty &&
                c.maxScore > c.minScore &&
                c.step > 0 &&
                (c.parentId == null || criteria.any((p) => p.id == c.parentId && p.isParent))));
    String pct(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(2);
    return Readiness(
      contestantsAssigned: contestants.length,
      judgesAssigned: assignments.length,
      requiredJudges: required.length,
      optionalJudges: assignments.length - required.length,
      requiredSubmitted: requiredSubmitted,
      submissionSummary: summary,
      criteria: criteria,
      effectiveScoredWeight: weight,
      weightValid: weightValid,
      criteriaValid: criteriaValid,
      readyToClose: round.status == 'open' && required.isNotEmpty && requiredSubmitted == required.length,
      items: [
        ReadinessItem('Contestants assigned', '${contestants.length} contestants ready', contestants.isNotEmpty),
        ReadinessItem('Judges assigned', '${assignments.length} judges assigned', assignments.isNotEmpty),
        ReadinessItem('Required judges', '${required.length} required judges', required.isNotEmpty),
        ReadinessItem(
          'Criteria weight',
          weightValid ? '100% effective scored weight' : '${pct(weight)}% effective scored weight · review required',
          weightValid,
        ),
        ReadinessItem(
          'Required submissions',
          '$requiredSubmitted / ${required.length} submitted',
          required.isNotEmpty && requiredSubmitted == required.length,
        ),
      ],
    );
  }

  List<ReopenRecord> getReopens(int roundId) => List.unmodifiable(_reopensByRound[roundId] ?? const []);

  List<AuditEvent> getAuditEvents() {
    final events = [..._auditEvents];
    if (!connected && !events.any((e) => e.type == 'submit' && e.roundId == 1 && e.judgeId == 3)) {
      events.add(AuditEvent(type: 'submit', roundId: 1, judgeId: 3, at: DateTime(2026, 9, 23, 21, 42), actor: 'Amanda Wijaya'));
    }
    return events..sort((a, b) => b.at.compareTo(a.at));
  }

  // --------------------------------------------------------- commands: masters

  void saveContestant(ContestantMaster item) {
    final i = _contestants.indexWhere((c) => c.id == item.id);
    if (i < 0) {
      _contestants.add(item);
    } else {
      _contestants[i] = item;
    }
    _save();
  }

  void saveJudge(JudgeMaster item) {
    final i = _judges.indexWhere((c) => c.id == item.id);
    if (i < 0) {
      _judges.add(item);
    } else {
      _judges[i] = item;
    }
    _save();
  }

  int nextContestantId() => _contestants.fold(0, (m, c) => math.max(m, c.id)) + 1;
  int nextJudgeId() => _judges.fold(0, (m, c) => math.max(m, c.id)) + 1;

  bool setEventSettings(EventSettings settings) {
    eventSettings = settings;
    return _save();
  }

  // ------------------------------------------------- commands: round configuration

  bool setRoundContestantAssignments(int roundId, List<int> ids) {
    if (getRound(roundId)?.status != 'draft' || getAdvancementForTarget(roundId) != null) return false;
    _contestantAssignments[roundId] = [...ids];
    _save();
    return true;
  }

  void setJudgeAssignment(int roundId, int judgeId, bool enabled) {
    if (getRound(roundId)?.status != 'draft') return;
    final list = _judgeAssignments.putIfAbsent(roundId, () => []);
    final a = list.where((x) => x.judgeId == judgeId).firstOrNull;
    if (a == null && enabled) {
      list.add(JudgeAssignment(judgeId: judgeId, roundId: roundId, required: eventSettings.defaultJudgeAssignmentRequired));
    } else if (a != null) {
      a.status = enabled ? 'assigned' : 'unassigned';
    }
    _save();
  }

  void setJudgeRequired(int roundId, int judgeId, bool required) {
    if (getRound(roundId)?.status != 'draft') return;
    final a = (_judgeAssignments[roundId] ?? const <JudgeAssignment>[])
        .where((x) => x.judgeId == judgeId && x.status == 'assigned')
        .firstOrNull;
    if (a != null) {
      a.required = required;
      _save();
    }
  }

  bool setCriteria(int roundId, List<AdminCriterion> criteria) {
    if (getRound(roundId)?.status != 'draft') return false;
    _criteriaByRound[roundId] = [for (final c in criteria) c.copy(roundId: roundId)];
    _save();
    return true;
  }

  // ----------------------------------------------------------- commands: lifecycle

  void _audit(String type, int? roundId, [int? judgeId, String reason = '']) {
    _auditEvents.add(AuditEvent(type: type, roundId: roundId, judgeId: judgeId, reason: reason, at: DateTime.now(), actor: actor));
  }

  bool canOpenRound(int roundId) {
    final round = getRound(roundId);
    final previous = getPreviousRound(roundId);
    if (round == null || round.status != 'draft') return false;
    if (previous != null && getAdvancement(previous.id) == null) return false;
    final r = getRoundReadiness(roundId);
    return r.contestantsAssigned > 0 && r.judgesAssigned > 0 && r.requiredJudges > 0 && r.weightValid && r.criteriaValid;
  }

  bool openRound(int roundId) {
    if (!canOpenRound(roundId)) return false;
    getRound(roundId)!.status = 'open';
    _audit('open', roundId);
    _save();
    return true;
  }

  bool closeRound(int roundId) {
    if (!getRoundReadiness(roundId).readyToClose) return false;
    getRound(roundId)!.status = 'closed';
    _audit('close', roundId);
    _save();
    return true;
  }

  // ----------------------------------------------------------- commands: governance

  AdminActionResult reopen(int roundId, int judgeId, String reason) {
    reason = reason.trim();
    final judge = getMonitoringJudges(roundId).where((j) => j.id == judgeId).firstOrNull;
    if (reason.isEmpty) return const AdminActionResult.fail('A reason is required.');
    if (getRound(roundId)?.status != 'open' ||
        judge == null ||
        !['submitted', 'resubmitted'].contains(judge.submissionStatus)) {
      return const AdminActionResult.fail('This action is not available now. Refresh and check round readiness.');
    }
    _reopensByRound.putIfAbsent(roundId, () => []).add(ReopenRecord(
          judgeId: judgeId,
          roundId: roundId,
          reason: reason,
          originalSubmittedAt: judge.submittedAt,
          reopenedAt: DateTime.now(),
          reopenedBy: actor,
        ));
    _submissionOverrides.putIfAbsent(roundId, () => {})[judgeId] = (status: 'reopened', submittedAt: judge.submittedAt);
    _audit('reopen', roundId, judgeId, reason);
    _save();
    return const AdminActionResult.ok();
  }

  /// excuse (reason required) | restore | remove (only without scoring activity)
  AdminActionResult updateJudgeAssignment(int roundId, int judgeId, String action, [String reason = '']) {
    reason = reason.trim();
    final assignment = (_judgeAssignments[roundId] ?? const <JudgeAssignment>[]).where((a) => a.judgeId == judgeId).firstOrNull;
    if (getRound(roundId)?.status != 'open' || assignment == null) {
      return const AdminActionResult.fail('Judge governance is available only while this round is open.');
    }
    final judge = getMonitoringJudges(roundId).where((j) => j.id == judgeId).firstOrNull;
    if (action == 'excuse' && assignment.status == 'assigned' && reason.isNotEmpty) {
      assignment
        ..status = 'excused'
        ..excuseReason = reason
        ..excusedAt = DateTime.now();
      _audit('excuse', roundId, judgeId, reason);
      _save();
      return const AdminActionResult.ok();
    }
    if (action == 'restore' && assignment.status == 'excused') {
      assignment.status = 'assigned';
      _audit('restore', roundId, judgeId);
      _save();
      return const AdminActionResult.ok();
    }
    if (action == 'remove' && assignment.status == 'assigned') {
      if (judge != null &&
          (judge.completed > 0 || ['submitted', 'resubmitted', 'reopened', 'in-progress'].contains(judge.submissionStatus))) {
        return const AdminActionResult.fail(
            'This judge already has scoring activity. Use Excused or Reopen governance instead.');
      }
      assignment.status = 'removed';
      _audit('remove', roundId, judgeId);
      _save();
      return const AdminActionResult.ok();
    }
    return AdminActionResult.fail(action == 'excuse' ? 'A reason is required.' : 'This action is not available for this judge.');
  }

  // --------------------------------------------------------------- results

  static const _reference = <int, Map<String, double>>{
    1: {'communication': 8.75, 'confidence': 9, 'substance': 8.5, 'evening-gown': 9.25, 'stage-presence': 9},
    2: {'communication': 8.5, 'confidence': 8.75, 'substance': 8.75, 'evening-gown': 9, 'stage-presence': 8.75},
  };

  List<AdminCriterion> scoredCriteria(int roundId) => getCriteria(roundId).where((c) => c.isScored && !c.isParent).toList();

  /// Prototype reference score sheet (no Admin API for judge sheets yet).
  Map<String, double> getJudgeScoreSheet(int roundId, int judgeId, int contestantId) {
    final criteria = scoredCriteria(roundId);
    return {
      for (var i = 0; i < criteria.length; i++)
        criteria[i].id: (roundId == 1 && judgeId == 3 && _reference[contestantId]?[criteria[i].id] != null)
            ? _reference[contestantId]![criteria[i].id]!
            : math.max(
                1,
                math.min(
                  10,
                  6.25 +
                      ((contestantId * 13) % 15) * 0.25 +
                      ((judgeId % 3) - 1) * 0.25 +
                      (((i * 2) % 3) - 1) * 0.25,
                ),
              ).toDouble(),
    };
  }

  double? calculateContestantJudgeTotal(int roundId, int judgeId, int contestantId) {
    final criteria = scoredCriteria(roundId);
    if (criteria.isEmpty) return null;
    final sheet = getJudgeScoreSheet(roundId, judgeId, contestantId);
    return criteria.fold<double>(0, (s, c) => s + sheet[c.id]! * c.weight / 10);
  }

  List<MonitoringJudge> getEligibleResultJudges(int roundId) => getMonitoringJudges(roundId)
      .where((j) =>
          j.assignmentStatus == 'assigned' &&
          j.required &&
          (j.submissionStatus == 'submitted' || j.submissionStatus == 'resubmitted'))
      .toList();

  RoundResult calculateRoundResults(int roundId) {
    final round = getRound(roundId);
    if (round == null) return const RoundResult.unavailable('Round not found.');
    if (round.status == 'finalized') {
      return _snapshots[roundId] ?? const RoundResult.unavailable('Finalized result snapshot is missing.');
    }
    if (connected && _loadedRounds.contains(roundId)) {
      return round.status == 'closed'
          ? _provisional[roundId] ?? const RoundResult.unavailable('The server has not calculated this result yet.')
          : const RoundResult.unavailable(
              'Results are unavailable while judging is open. Close the round after all required judges have submitted.');
    }
    if (round.status != 'closed') {
      return const RoundResult.unavailable(
          'Results are unavailable while judging is open. Close the round after all required judges have submitted.');
    }
    return _computeResults(roundId);
  }

  RoundResult _computeResults(int roundId) {
    final ready = getRoundReadiness(roundId);
    if (ready.requiredJudges == 0 || ready.requiredSubmitted != ready.requiredJudges) {
      return const RoundResult.unavailable('All active Required judges must submit before official results can be calculated.');
    }
    final eligible = getEligibleResultJudges(roundId);
    final contestants = getRoundContestants(roundId);
    if (eligible.isEmpty || contestants.isEmpty) {
      return const RoundResult.unavailable('No eligible judges or contestants are available.');
    }
    final monitoring = getMonitoringJudges(roundId);
    final items = <ResultItem>[];
    for (final c in contestants) {
      final scores = [
        for (final j in monitoring)
          () {
            final included = eligible.any((e) => e.id == j.id);
            final hasHistory =
                j.completed >= c.number || ['submitted', 'resubmitted', 'reopened'].contains(j.submissionStatus);
            final exclusion = included
                ? ''
                : j.assignmentStatus == 'excused'
                    ? 'Excused — Not Counted'
                    : j.assignmentStatus == 'removed'
                        ? 'Removed — Not Counted'
                        : !j.required
                            ? 'Optional — Not Counted'
                            : 'Not Submitted — Not Counted';
            return JudgeScoreEntry(
              judgeId: j.id,
              judgeNumber: j.number,
              judgeName: j.name,
              total: hasHistory ? calculateContestantJudgeTotal(roundId, j.id, c.id) : null,
              included: included,
              exclusion: exclusion,
              criteriaScores: hasHistory ? getJudgeScoreSheet(roundId, j.id, c.id) : const {},
            );
          }(),
      ];
      final counted = scores.where((s) => s.included).toList();
      if (counted.any((s) => s.total == null)) {
        return const RoundResult.unavailable(
            'An eligible judge score sheet is incomplete. Official ranking cannot be calculated.');
      }
      final average = counted.fold<double>(0, (s, e) => s + e.total!) / counted.length;
      items.add(ResultItem(
        contestantId: c.id,
        number: c.number,
        name: c.name,
        profesi: c.profesi,
        photo: c.photo,
        combinedScore: double.parse(average.toStringAsFixed(2)),
        eligibleJudgeCount: counted.length,
        judgeScores: scores,
      ));
    }
    items.sort((a, b) => b.combinedScore != a.combinedScore ? b.combinedScore.compareTo(a.combinedScore) : a.number.compareTo(b.number));
    for (var i = 0; i < items.length; i++) {
      final prev = i > 0 ? items[i - 1] : null;
      final next = i + 1 < items.length ? items[i + 1] : null;
      items[i].rank = prev != null && prev.combinedScore == items[i].combinedScore ? prev.rank : i + 1;
      items[i].tied = (prev != null && prev.combinedScore == items[i].combinedScore) ||
          (next != null && next.combinedScore == items[i].combinedScore);
    }
    return RoundResult(
      roundId: roundId,
      eligibleJudgeIds: [for (final e in eligible) e.id],
      contestantCount: contestants.length,
      items: items,
    );
  }

  /// unavailable | provisional | finalized
  String getRoundResultStatus(int roundId) {
    final round = getRound(roundId);
    if (round == null) return 'unavailable';
    if (round.status == 'finalized' && _snapshots[roundId] != null) return 'finalized';
    return calculateRoundResults(roundId).available ? 'provisional' : 'unavailable';
  }

  RoundResult? getResultSnapshot(int roundId) => _snapshots[roundId];
  bool isResultVisible(int roundId) => getRoundResultStatus(roundId) == 'finalized' && _visibility[roundId] == true;
  bool isTieAcknowledged(int roundId) => _tieAcknowledged[roundId] == true;

  bool acknowledgeTie(int roundId) {
    final result = calculateRoundResults(roundId);
    if (!result.available || !result.hasTie || result.finalized) return false;
    _tieAcknowledged[roundId] = true;
    _save();
    return true;
  }

  /// Audit "results calculated" once per round (when first viewed).
  void noteResultsCalculated(int roundId) {
    final result = calculateRoundResults(roundId);
    if (!result.available || result.finalized) return;
    if (!_auditEvents.any((e) => e.type == 'results-calculated' && e.roundId == roundId)) {
      _audit('results-calculated', roundId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _save());
    }
  }

  bool finalizeResults(int roundId) {
    final round = getRound(roundId);
    final result = calculateRoundResults(roundId);
    if (round == null ||
        round.status != 'closed' ||
        !result.available ||
        result.eligibleJudgeCount != getRoundReadiness(roundId).requiredJudges ||
        (result.hasTie && !isTieAcknowledged(roundId))) {
      return false;
    }
    if (!_auditEvents.any((e) => e.type == 'results-calculated' && e.roundId == roundId)) {
      _audit('results-calculated', roundId);
    }
    _snapshots[roundId] = RoundResult(
      roundId: roundId,
      eligibleJudgeIds: result.eligibleJudgeIds,
      contestantCount: result.contestantCount,
      items: result.items,
      finalized: true,
      finalizedAt: DateTime.now(),
      finalizedBy: actor,
    );
    _visibility[roundId] = eventSettings.resultVisibilityAfterFinalization;
    round.status = 'finalized';
    _audit('finalize', roundId);
    _save();
    return true;
  }

  bool setResultVisibility(int roundId, bool visible) {
    if (getRoundResultStatus(roundId) != 'finalized') return false;
    if (_visibility[roundId] == visible) return true;
    _visibility[roundId] = visible;
    _audit(visible ? 'visibility-on' : 'visibility-off', roundId);
    _save();
    return true;
  }

  // ----------------------------------------------------------- advancement

  Advancement? getAdvancement(int roundId) => _advancementBySource[roundId];
  Advancement? getAdvancementForTarget(int roundId) =>
      _advancementBySource.values.where((a) => a.targetRoundId == roundId).firstOrNull;

  List<int> getDefaultAdvancementIds(int roundId) {
    final info = _advancementInfo[roundId];
    if (info != null) return info.suggestedIds;
    final source = getRound(roundId);
    final snapshot = getResultSnapshot(roundId);
    if (source == null || snapshot == null) return const [];
    return [for (final i in snapshot.items.take(source.advancementCount ?? 0)) i.contestantId];
  }

  bool hasAdvancementCutoffTie(int roundId) {
    final info = _advancementInfo[roundId];
    if (info != null) return info.cutoffTie;
    final count = getRound(roundId)?.advancementCount ?? 0;
    final snapshot = getResultSnapshot(roundId);
    return snapshot != null &&
        count > 0 &&
        snapshot.items.length > count &&
        snapshot.items[count - 1].combinedScore == snapshot.items[count].combinedScore;
  }

  ({bool ok, String? message, bool manual, bool cutoffTie}) validateAdvancement(int roundId, List<int> ids, String reason) {
    final info = _advancementInfo[roundId];
    if (info != null && !info.canConfirm) {
      return (ok: false, message: info.blockingReason ?? 'Advancement is not available now.', manual: false, cutoffTie: info.cutoffTie);
    }
    final source = getRound(roundId), target = getNextRound(roundId), snapshot = getResultSnapshot(roundId);
    if (source == null ||
        source.status != 'finalized' ||
        snapshot == null ||
        target == null ||
        target.status != 'draft' ||
        isAdvancementConfirmed(roundId)) {
      return (ok: false, message: 'Advancement requires finalized results and an unstarted target round.', manual: false, cutoffTie: false);
    }
    final count = source.advancementCount ?? 0;
    if (count == 0 ||
        ids.length != count ||
        ids.toSet().length != count ||
        ids.any((id) => !snapshot.items.any((i) => i.contestantId == id))) {
      return (ok: false, message: 'Select exactly $count contestants from the official result.', manual: false, cutoffTie: false);
    }
    final defaults = getDefaultAdvancementIds(roundId);
    final manual = ids.any((id) => !defaults.contains(id));
    final cutoffTie = hasAdvancementCutoffTie(roundId);
    if ((manual || cutoffTie) && reason.trim().isEmpty) {
      return (
        ok: false,
        message: cutoffTie
            ? 'Resolve the qualification-cut tie and provide a reason.'
            : 'A reason is required when selection differs from the official Top $count.',
        manual: manual,
        cutoffTie: cutoffTie,
      );
    }
    return (ok: true, message: null, manual: manual || cutoffTie, cutoffTie: cutoffTie);
  }

  AdminActionResult confirmAdvancement(int roundId, List<int> ids, String reason) {
    final check = validateAdvancement(roundId, ids, reason);
    if (!check.ok) return AdminActionResult.fail(check.message);
    final snapshot = getResultSnapshot(roundId)!;
    final target = getNextRound(roundId)!;
    final record = Advancement(
      sourceRoundId: roundId,
      targetRoundId: target.id,
      selectedContestantIds: [...ids],
      snapshotId: '$roundId:${snapshot.finalizedAt?.toIso8601String()}',
      method: check.manual ? 'manual' : 'top_n',
      reason: reason.trim(),
      confirmedBy: actor,
      confirmedAt: DateTime.now(),
    );
    _advancementBySource[roundId] = record;
    _contestantAssignments[target.id] = [...ids];
    _advancementHistory.add({'type': 'advancement-confirmed', 'record': record.toJson()});
    _audit('advancement-confirmed', roundId, null, record.reason.isNotEmpty ? record.reason : '${ids.length} contestants → ${target.name}');
    _save();
    return const AdminActionResult.ok();
  }

  bool resetAdvancement(int roundId, String reason) {
    final record = getAdvancement(roundId);
    reason = reason.trim();
    if (record == null || reason.isEmpty || getRound(record.targetRoundId)?.status != 'draft') return false;
    _contestantAssignments[record.targetRoundId] = [];
    _advancementBySource.remove(roundId);
    _advancementHistory.add({'type': 'advancement-reset', 'record': record.toJson(), 'reason': reason, 'at': DateTime.now().toIso8601String()});
    _audit('advancement-reset', roundId, null, reason);
    _save();
    return true;
  }

  bool adjustAdvancementAssignment(int targetRoundId, List<int> ids, String reason) {
    final record = getAdvancementForTarget(targetRoundId);
    reason = reason.trim();
    if (record == null || getRound(targetRoundId)?.status != 'draft' || reason.isEmpty) return false;
    if (ids.toSet().length != ids.length || ids.any((id) => getContestant(id) == null)) return false;
    _contestantAssignments[targetRoundId] = [...ids];
    record.adjustments.add(AdvancementAdjustment([...ids], reason, DateTime.now(), actor));
    _advancementHistory.add({
      'type': 'advancement-adjusted',
      'sourceRoundId': record.sourceRoundId,
      'targetRoundId': targetRoundId,
      'contestantIds': ids,
      'reason': reason,
      'at': DateTime.now().toIso8601String(),
    });
    _audit('advancement-adjusted', record.sourceRoundId, null, reason);
    _save();
    return true;
  }

  bool copyRoundConfiguration(int sourceRoundId, int targetRoundId, {required bool judges, required bool criteria}) {
    if (getRound(sourceRoundId) == null ||
        getRound(targetRoundId)?.status != 'draft' ||
        getNextRound(sourceRoundId)?.id != targetRoundId ||
        (!judges && !criteria)) {
      return false;
    }
    if (judges) {
      _judgeAssignments[targetRoundId] = [
        for (final a in _judgeAssignments[sourceRoundId] ?? const <JudgeAssignment>[])
          if (a.status == 'assigned') JudgeAssignment(judgeId: a.judgeId, roundId: targetRoundId, required: a.required),
      ];
    }
    if (criteria) {
      _criteriaByRound[targetRoundId] = [for (final c in getCriteria(sourceRoundId)) c.copy(roundId: targetRoundId)];
    }
    _audit('configuration-copied', targetRoundId, null, 'From ${getRound(sourceRoundId)!.name}');
    _save();
    return true;
  }
}

/// A judge's progress in one round (`monitoring.judges[]`).
class _JudgeProgress {
  const _JudgeProgress({
    required this.sheets,
    required this.done,
    required this.status,
    required this.submittedSheetIds,
    this.submittedAt,
  });
  final int sheets;
  final bool done;
  final String status; // not-started | in-progress | submitted | resubmitted | reopened
  final List<int> submittedSheetIds;
  final DateTime? submittedAt;

  factory _JudgeProgress.fromApi(Map<String, dynamic> j) {
    final sheets = [for (final s in (j['sheets'] as List? ?? const [])) if (s is Map) Map<String, dynamic>.from(s)];
    String st(Map<String, dynamic> s) => '${s['status'] ?? ''}'.toLowerCase();
    final done = j['is_done'] == true;
    final times = [for (final s in sheets) DateTime.tryParse('${s['submitted_at']}')].whereType<DateTime>().toList()..sort();
    return _JudgeProgress(
      sheets: sheets.length,
      done: done,
      status: sheets.any((s) => st(s) == 'reopened')
          ? 'reopened'
          : done
              ? (sheets.any((s) => st(s) == 'resubmitted') ? 'resubmitted' : 'submitted')
              : sheets.isEmpty
                  ? 'not-started'
                  : 'in-progress',
      submittedSheetIds: [
        for (final s in sheets)
          if (['submitted', 'resubmitted', 'locked'].contains(st(s)) && s['score_sheet_id'] is num)
            (s['score_sheet_id'] as num).toInt(),
      ],
      submittedAt: times.lastOrNull,
    );
  }
}
