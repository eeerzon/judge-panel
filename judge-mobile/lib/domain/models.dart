// Typed domain models for the Judge flow, parsed from the KREEN judge API
// (`/api/v1/judge/...`). Shapes follow the live responses, which differ a
// little from the published examples (e.g. `access_token` is a string,
// contestant identity lives in `finalis`). The login `judge.id` is an int for
// judges and a string (e.g. "89549734435e2d5d38e1") for owners, so it is kept
// as a string.

import 'dart:math' as math;

double? _toDouble(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

int? _toInt(Object? v) => switch (v) {
      int n => n,
      num n => n.toInt(),
      String s => int.tryParse(s),
      _ => null,
    };

DateTime? _toDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

String? _toStr(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

/// `actor_type` from the login response — decides which workspaces the
/// Mode Selector offers: owner → Admin + Judge, admin → Admin, judge → Judge.
enum ActorType {
  owner,
  admin,
  judge;

  bool get canAdmin => this != judge;
  bool get canJudge => this != admin;

  /// Unknown or missing values fall back to [judge] (the most restricted).
  static ActorType parse(Object? v) => switch ('$v'.toLowerCase()) {
        'owner' => owner,
        'admin' => admin,
        _ => judge,
      };
}

class JudgeProfile {
  const JudgeProfile({required this.id, required this.name, required this.email, this.merchantId});

  final String id;
  final String name;
  final String email;
  final String? merchantId;

  String get identityLabel => 'Judge · $name';

  factory JudgeProfile.fromJson(Map<String, dynamic> j) => JudgeProfile(
        id: _toStr(j['id']) ?? '0',
        name: _toStr(j['name']) ?? '',
        email: _toStr(j['email']) ?? '',
        merchantId: _toStr(j['id_merchant']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'id_merchant': merchantId};
}

enum RoundStatus {
  draft,
  open,
  closed,
  finalized;

  static RoundStatus parse(Object? v) =>
      RoundStatus.values.where((s) => s.name == '$v'.toLowerCase()).firstOrNull ?? RoundStatus.draft;
}

class Round {
  const Round({
    required this.id,
    required this.name,
    required this.status,
    this.orderNo = 0,
    this.resultsVisibleToJudges = false,
    this.eventName,
    this.eventBanner,
    this.eventTheme,
    this.eventId,
    this.openedAt,
    this.createdAt,
  });

  final int id;
  final String name;
  final RoundStatus status;
  final int orderNo;
  final bool resultsVisibleToJudges;

  /// `id_vote` — groups My Rounds per event.
  final String? eventId;

  /// `vote.judul_vote` (only present in the rounds list).
  final String? eventName;

  /// `vote.banner` image URL (only present in the rounds list).
  final String? eventBanner;

  /// Raw `vote.theme` (only in the rounds list; null when the server sends
  /// none). Read by JudgeThemeStore — `source: "vote"` = no Judge Mode theme.
  final Map<String, dynamic>? eventTheme;
  final DateTime? openedAt;
  final DateTime? createdAt;

  factory Round.fromJson(Map<String, dynamic> j) {
    final vote = j['vote'];
    return Round(
      id: _toInt(j['id']) ?? 0,
      name: _toStr(j['name']) ?? 'Round',
      status: RoundStatus.parse(j['status']),
      orderNo: _toInt(j['order_no']) ?? 0,
      resultsVisibleToJudges: j['result_visibility'] == true,
      eventName: vote is Map ? _toStr(vote['judul_vote']) : null,
      eventBanner: vote is Map ? _toStr(vote['banner']) : null,
      eventTheme: vote is Map && vote['theme'] is Map ? Map<String, dynamic>.from(vote['theme'] as Map) : null,
      eventId: _toStr(j['id_vote']) ?? (vote is Map ? _toStr(vote['id_vote']) : null),
      openedAt: _toDate(j['opened_at']),
      createdAt: _toDate(j['created_at']),
    );
  }

  /// The detail endpoint has no `vote`; keep the event name/banner/id from
  /// the list.
  Round withEventName(String? name, [String? banner, String? listedEventId]) => Round(
        id: id,
        name: this.name,
        status: status,
        orderNo: orderNo,
        resultsVisibleToJudges: resultsVisibleToJudges,
        eventName: eventName ?? name,
        eventBanner: eventBanner ?? banner,
        eventTheme: eventTheme,
        eventId: eventId ?? listedEventId,
        openedAt: openedAt,
        createdAt: createdAt,
      );
}

/// A round participant (`RoundContestant`) with its `finalis` master identity.
class Contestant {
  const Contestant({
    required this.id,
    required this.finalisId,
    required this.number,
    required this.name,
    this.subtitle = '',
    this.photoUrl,
  });

  /// `round_contestant_id` — the id used by score-sheet endpoints.
  final int id;
  final String finalisId;
  final int number;
  final String name;

  /// Secondary line under the name (profession / additional name).
  final String subtitle;
  final String? photoUrl;

  String get numberLabel => '#${number.toString().padLeft(2, '0')}';

  factory Contestant.fromJson(Map<String, dynamic> j) {
    final f = j['finalis'] is Map ? Map<String, dynamic>.from(j['finalis'] as Map) : const <String, dynamic>{};
    final id = _toInt(j['id']) ?? 0;
    return Contestant(
      id: id,
      finalisId: _toStr(j['id_finalis']) ?? _toStr(f['id_finalis']) ?? '',
      number: _toInt(f['nomor_urut']) ?? id,
      name: _toStr(f['nama_finalis']) ?? 'Contestant $id',
      subtitle: _toStr(f['profesi']) ?? _toStr(f['nama_tambahan']) ?? '',
      photoUrl: _toStr(f['poster_finalis']),
    );
  }

  Contestant copyWithName(String? name) => name == null || name.isEmpty
      ? this
      : Contestant(id: id, finalisId: finalisId, number: number, name: name, subtitle: subtitle, photoUrl: photoUrl);
}

class Criterion {
  const Criterion({
    required this.id,
    required this.label,
    required this.weight,
    required this.min,
    required this.max,
    required this.step,
    this.description,
    this.parentId,
    this.isScored = true,
    this.quickScore,
    this.standalone = false,
  });

  final int id;
  final String label;
  final String? description;
  final double weight;
  final double min;
  final double max;
  final double step;
  final int? parentId;
  final bool isScored;

  /// Quick-score presets. Kept only for "Confidence" on a 1–10 scale, like
  /// the prototype (FR-4) — deliberately not extended to other criteria.
  final List<double>? quickScore;

  /// Single criterion without a parent group: only the section heading shows.
  final bool standalone;

  String get key => '$id';

  /// Decimals needed to show a value on this criterion's step (8.75 vs 80).
  int get decimals => step == step.roundToDouble() ? 0 : 2;

  factory Criterion.fromJson(Map<String, dynamic> j) {
    final min = _toDouble(j['min_points']) ?? 0;
    final max = _toDouble(j['max_points']) ?? 10;
    final label = _toStr(j['name']) ?? 'Criterion';
    // No step from the server → 0.25 on a ≤10 scale (prototype rule), else 1.
    final step = _toDouble(j['step']) ?? (max <= 10 ? 0.25 : 1);
    final quick = label.toLowerCase() == 'confidence' && max == 10 ? const [7.0, 8.0, 9.0, 10.0] : null;
    return Criterion(
      id: _toInt(j['id']) ?? 0,
      label: label,
      description: _toStr(j['description']),
      weight: _toDouble(j['weight']) ?? 0,
      min: min,
      max: math.max(max, min),
      step: step <= 0 ? 1 : step,
      parentId: _toInt(j['parent_id']),
      isScored: j['is_scored'] != false,
      quickScore: quick,
    );
  }

  Criterion asStandalone(bool value) => Criterion(
        id: id,
        label: label,
        description: description,
        weight: weight,
        min: min,
        max: max,
        step: step,
        parentId: parentId,
        isScored: isScored,
        quickScore: quickScore,
        standalone: value,
      );
}

class ScoringSection {
  const ScoringSection({required this.heading, required this.weight, required this.criteria});
  final String heading;
  final double weight;
  final List<Criterion> criteria;
}

/// Groups the flat criteria list into sections — same rule as the prototype's
/// Admin bridge: a criterion that has children is a heading (never scored,
/// never double-counted); a scored criterion without a parent is its own
/// standalone section.
List<ScoringSection> buildSections(List<Criterion> all) {
  final parentIds = {for (final c in all) if (c.parentId != null) c.parentId!};
  final sections = <({String heading, int? parentId, List<Criterion> items})>[];
  for (final c in all) {
    if (parentIds.contains(c.id)) {
      sections.add((heading: c.label, parentId: c.id, items: <Criterion>[]));
      continue;
    }
    if (!c.isScored) continue;
    final parent = c.parentId == null ? null : sections.where((s) => s.parentId == c.parentId).firstOrNull;
    if (parent != null) {
      parent.items.add(c.asStandalone(false));
    } else {
      sections.add((heading: c.label, parentId: null, items: [c.asStandalone(c.parentId == null)]));
    }
  }
  return [
    for (final s in sections)
      if (s.items.isNotEmpty)
        ScoringSection(heading: s.heading, weight: s.items.fold(0, (sum, c) => sum + c.weight), criteria: s.items),
  ];
}

/// Derived contestant status (FR-1). Never stored — recomputed from the
/// number of filled criteria.
enum ScoreStatus { notStarted, draft, scored }

class StatusInfo {
  const StatusInfo(this.status, this.scoredCount, this.total);
  final ScoreStatus status;
  final int scoredCount;
  final int total;

  String get label => switch (status) {
        ScoreStatus.scored => '✓ Scored',
        ScoreStatus.draft => 'Draft · $scoredCount / $total criteria',
        ScoreStatus.notStarted => 'Not Scored',
      };
}

class StatusCounts {
  const StatusCounts({required this.scored, required this.draft, required this.notStarted, required this.total});
  final int scored;
  final int draft;
  final int notStarted;
  final int total;
}

/// Server score-sheet statuses that mean "locked, already submitted".
const kLockedSheetStatuses = {'submitted', 'resubmitted', 'locked'};

/// One contestant row of `GET/POST .../score-sheet` and `.../review`.
class ScoreSheetRow {
  const ScoreSheetRow({
    required this.contestantId,
    required this.name,
    required this.sheetStatus,
    required this.scores,
    this.comment,
  });

  final int contestantId;
  final String? name;
  final String sheetStatus;

  /// criterion id → raw score (null = empty)
  final Map<int, double?> scores;

  /// First non-empty per-criterion comment — the app edits one note per contestant.
  final String? comment;

  factory ScoreSheetRow.fromJson(Map<String, dynamic> j) {
    final scores = <int, double?>{};
    String? comment;
    for (final s in (j['scores'] as List? ?? const [])) {
      if (s is! Map) continue;
      final id = _toInt(s['round_criteria_id']);
      if (id == null) continue;
      scores[id] = _toDouble(s['raw_score']);
      comment ??= _toStr(s['comment']);
    }
    return ScoreSheetRow(
      contestantId: _toInt(j['round_contestant_id']) ?? 0,
      name: _toStr(j['nama_finalis']),
      sheetStatus: (_toStr(j['sheet_status']) ?? 'not_started').toLowerCase(),
      scores: scores,
      comment: comment,
    );
  }
}

/// Body row for `POST .../score-sheet`.
class ScoreInput {
  const ScoreInput({required this.contestantId, required this.criterionId, required this.rawScore, this.comment});
  final int contestantId;
  final int criterionId;
  final double? rawScore;
  final String? comment;

  Map<String, dynamic> toJson() => {
        'round_contestant_id': contestantId,
        'round_criteria_id': criterionId,
        'raw_score': rawScore,
        'comment': comment,
      };
}

/// One row of an official result — the only result shape a Judge may see.
class ResultItem {
  const ResultItem({
    required this.rank,
    required this.tied,
    required this.number,
    required this.name,
    required this.subtitle,
    required this.combinedScore,
  });
  final int rank;
  final bool tied;
  final int number;
  final String name;
  final String subtitle;
  final double combinedScore;

  /// Reads both shapes: flat (`rank`, `combined_score`, `finalis`) and the
  /// server's result rows (`rank_no`, `avg_score`, `contestant.finalis`) —
  /// the latter used to fall through to 0 for every score.
  factory ResultItem.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
    final contestant = map(j['contestant']);
    final f = j['finalis'] is Map ? map(j['finalis']) : map(contestant['finalis']);
    return ResultItem(
      rank: _toInt(j['rank']) ?? _toInt(j['rank_no']) ?? 0,
      tied: j['tied'] == true || j['is_tied'] == true,
      number: _toInt(j['nomor_urut']) ?? _toInt(f['nomor_urut']) ?? 0,
      name: _toStr(j['nama_finalis']) ?? _toStr(f['nama_finalis']) ?? '',
      subtitle: _toStr(j['profesi']) ?? _toStr(f['profesi']) ?? '',
      combinedScore: _toDouble(j['combined_score']) ??
          _toDouble(j['avg_score']) ??
          _toDouble(j['score']) ??
          _toDouble(j['total_score']) ??
          _toDouble(j['accumulated_score']) ??
          0,
    );
  }

  ResultItem withTied(bool value) =>
      ResultItem(rank: rank, tied: value, number: number, name: name, subtitle: subtitle, combinedScore: combinedScore);
}

class ResultSnapshot {
  const ResultSnapshot({this.computedAt, this.isFinal = false, this.aggregationMode, this.items = const []});
  final DateTime? computedAt;
  final bool isFinal;
  final String? aggregationMode;
  final List<ResultItem> items;

  factory ResultSnapshot.fromJson(Map<String, dynamic> j) {
    final raw = j['items'] ?? j['rankings'] ?? j['results'];
    final items = [
      if (raw is List)
        for (final r in raw)
          if (r is Map) ResultItem.fromJson(Map<String, dynamic>.from(r)),
    ]..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : a.number.compareTo(b.number));
    return ResultSnapshot(
      computedAt: _toDate(j['computed_at']),
      isFinal: j['is_final'] == true,
      aggregationMode: _toStr(j['aggregation_mode']),
      // No tie flag from the server: equal scores share a rank (a tie).
      items: [
        for (final i in items)
          i.tied ? i : i.withTied(items.where((o) => o.combinedScore == i.combinedScore).length > 1),
      ],
    );
  }
}

/// Connection/sync indicator shown in Standby + Gallery headers.
enum ConnectionStateKind { online, syncing, synced, offline }
