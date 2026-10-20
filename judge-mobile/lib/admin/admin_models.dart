// Admin domain models — typed port of the structures in
// judge-prototype/admin/admin-data.js + admin-domain.js.
//
// Events, rounds and the contestant master come from the Admin API
// (`/judge/admin/...`, parsed by the `fromApi` factories). Everything the API
// does not expose yet is prototype data persisted locally by AdminStore
// (like the prototype's `kreenAdminConfiguration`).

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
double _num(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

/// A server id: an opaque string since 2026-10-09 (e.g. "bf853c108eed58075240").
String _sid(Object? v) => v == null ? '' : '$v'.trim();
String? _sidOrNull(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
/// Server timestamp: ISO with a zone as given; a zone-less one
/// (`2026-10-01 08:40:49`, Laravel default) is WIB (UTC+7).
DateTime? _serverTime(Object? v) {
  final text = '${v ?? ''}'.trim();
  if (text.isEmpty) return null;
  final zoned = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(text);
  return DateTime.tryParse(zoned ? text : '${text.replaceFirst(' ', 'T')}+07:00');
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

class AdminRound {
  AdminRound({
    required this.id,
    required this.order,
    required this.name,
    required this.status,
    this.advancementCount,
    this.promoteMode = 'auto_top_n',
    this.favoritPromoteEnabled = false,
    this.resultVisibility = false,
    this.criteriaCount,
    this.contestantsCount,
    this.judgesCount,
    this.finalizedAt,
    this.tieAcknowledgedAt,
  });
  final String id;
  final int order;
  final String name;
  String status; // draft | open | closed | finalized
  final int? advancementCount;

  /// API only: `manual` | `auto_top_n`, favourite-vote promotion, published
  /// results and the configured counts (used to size prototype data).
  final String promoteMode;
  final bool favoritPromoteEnabled, resultVisibility;
  final int? criteriaCount, contestantsCount, judgesCount;
  final DateTime? finalizedAt, tieAcknowledgedAt;

  /// `GET /judge/admin/events/{idVote}/rounds` item.
  factory AdminRound.fromApi(Map<String, dynamic> j) => AdminRound(
        id: _sid(j['id']),
        order: _int(j['order_no'], 1),
        name: _text(j['name']) ?? 'Round',
        status: switch (j['status']) { 'open' || 'closed' || 'finalized' => j['status'] as String, _ => 'draft' },
        advancementCount: j['promote_top_n'] == null ? null : _int(j['promote_top_n']),
        promoteMode: _text(j['promote_mode']) ?? 'auto_top_n',
        favoritPromoteEnabled: j['favorit_promote_enabled'] == true,
        resultVisibility: j['result_visibility'] == true,
        criteriaCount: j['criteria_count'] == null ? null : _int(j['criteria_count']),
        contestantsCount: j['contestants_count'] == null ? null : _int(j['contestants_count']),
        judgesCount: j['judges_count'] == null ? null : _int(j['judges_count']),
        finalizedAt: _date(j['finalized_at']),
        tieAcknowledgedAt: _date(j['tie_acknowledged_at']),
      );
}

/// `rounds` counters of a dashboard event.
class RoundCounts {
  const RoundCounts({this.total = 0, this.draft = 0, this.open = 0, this.closed = 0, this.finalized = 0});
  final int total, draft, open, closed, finalized;

  factory RoundCounts.fromApi(Object? raw) {
    final j = raw is Map ? raw : const {};
    return RoundCounts(
      total: _int(j['total']),
      draft: _int(j['draft']),
      open: _int(j['open']),
      closed: _int(j['closed']),
      finalized: _int(j['finalized']),
    );
  }
}

/// An event (`vote`) the admin manages — `GET /judge/admin/dashboard` item and
/// the header of `GET /judge/admin/events/{idVote}`.
class AdminEvent {
  const AdminEvent({
    required this.id,
    required this.title,
    this.banner,
    this.active = true,
    this.votingOpensAt,
    this.votingClosesAt,
    this.grandFinalOn,
    this.roundCounts = const RoundCounts(),
    this.totalFinalists,
    this.slug,
  });

  final String id; // id_vote
  final String title;

  /// Public results link: `#/<slug>/round_<n>` (event detail only).
  final String? slug;
  final String? banner;
  final bool active;
  final DateTime? votingOpensAt, votingClosesAt, grandFinalOn;
  final RoundCounts roundCounts;
  final int? totalFinalists;

  factory AdminEvent.fromApi(Map<String, dynamic> j) {
    final rounds = j['rounds'];
    return AdminEvent(
      id: '${j['id_vote']}',
      title: _text(j['judul_vote']) ?? 'Untitled event',
      banner: _text(j['banner']),
      active: j['flag_aktif'] == true || _int(j['flag_aktif']) == 1,
      votingOpensAt: _date(j['tanggal_buka_vote']),
      votingClosesAt: _date(j['tanggal_tutup_vote']),
      grandFinalOn: _date(j['tanggal_grandfinal_mulai']),
      // Dashboard: counters map; event detail: the round list.
      roundCounts: rounds is List
          ? RoundCounts(
              total: rounds.length,
              draft: rounds.where((r) => r is Map && r['status'] == 'draft').length,
              open: rounds.where((r) => r is Map && r['status'] == 'open').length,
              closed: rounds.where((r) => r is Map && r['status'] == 'closed').length,
              finalized: rounds.where((r) => r is Map && r['status'] == 'finalized').length,
            )
          : RoundCounts.fromApi(rounds),
      totalFinalists: j['total_finalis'] == null ? null : _int(j['total_finalis']),
      slug: _text(j['slug']),
    );
  }
}

/// One page of `GET /judge/admin/dashboard`.
class AdminEventPage {
  const AdminEventPage({required this.items, this.currentPage = 1, this.lastPage = 1, this.total = 0});
  final List<AdminEvent> items;
  final int currentPage, lastPage, total;
}

/// `GET /judge/admin/events/{idVote}`.
class AdminEventDetail {
  const AdminEventDetail({required this.event, required this.rounds});
  final AdminEvent event;
  final List<AdminRound> rounds;
}

class EventSettings {
  const EventSettings({
    this.eventName = 'King & Queen of the Pacific',
    this.eventYear = '2026',
    this.shortName = 'KQ Pacific',
    this.minScore = 1,
    this.maxScore = 10,
    this.step = 0.25,
    this.defaultCriterionRequired = true,
    this.defaultJudgeAssignmentRequired = true,
    this.resultVisibilityAfterFinalization = false,
  });

  final String eventName, eventYear, shortName;
  final double minScore, maxScore, step;
  final bool defaultCriterionRequired, defaultJudgeAssignmentRequired, resultVisibilityAfterFinalization;

  EventSettings copyWith({
    String? eventName,
    String? eventYear,
    String? shortName,
    double? minScore,
    double? maxScore,
    double? step,
    bool? defaultCriterionRequired,
    bool? defaultJudgeAssignmentRequired,
    bool? resultVisibilityAfterFinalization,
  }) =>
      EventSettings(
        eventName: eventName ?? this.eventName,
        eventYear: eventYear ?? this.eventYear,
        shortName: shortName ?? this.shortName,
        minScore: minScore ?? this.minScore,
        maxScore: maxScore ?? this.maxScore,
        step: step ?? this.step,
        defaultCriterionRequired: defaultCriterionRequired ?? this.defaultCriterionRequired,
        defaultJudgeAssignmentRequired: defaultJudgeAssignmentRequired ?? this.defaultJudgeAssignmentRequired,
        resultVisibilityAfterFinalization: resultVisibilityAfterFinalization ?? this.resultVisibilityAfterFinalization,
      );

  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'eventYear': eventYear,
        'shortName': shortName,
        'minScore': minScore,
        'maxScore': maxScore,
        'step': step,
        'defaultCriterionRequired': defaultCriterionRequired,
        'defaultJudgeAssignmentRequired': defaultJudgeAssignmentRequired,
        'resultVisibilityAfterFinalization': resultVisibilityAfterFinalization,
      };

  factory EventSettings.fromJson(Map<String, dynamic> j) {
    const d = EventSettings();
    return EventSettings(
      eventName: j['eventName'] as String? ?? d.eventName,
      eventYear: j['eventYear'] as String? ?? d.eventYear,
      shortName: j['shortName'] as String? ?? d.shortName,
      minScore: _num(j['minScore'], d.minScore),
      maxScore: _num(j['maxScore'], d.maxScore),
      step: _num(j['step'], d.step),
      defaultCriterionRequired: j['defaultCriterionRequired'] as bool? ?? d.defaultCriterionRequired,
      defaultJudgeAssignmentRequired: j['defaultJudgeAssignmentRequired'] as bool? ?? d.defaultJudgeAssignmentRequired,
      resultVisibilityAfterFinalization:
          j['resultVisibilityAfterFinalization'] as bool? ?? d.resultVisibilityAfterFinalization,
    );
  }

  @override
  bool operator ==(Object other) => other is EventSettings && _mapEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

bool _mapEquals(Map a, Map b) => a.length == b.length && a.keys.every((k) => a[k] == b[k]);

class ContestantMaster {
  ContestantMaster({
    required this.id,
    required this.number,
    required this.name,
    required this.profesi,
    this.photo = '',
    this.status = 'active',
    this.externalId,
    this.additionalName,
    this.age,
  });
  final int id;
  int number;

  /// `nama_finalis`, `profesi`.
  String name, profesi;

  /// `nama_tambahan`, `usia` — null when the API has none. (Vote counts are
  /// not shown in judging.)
  String? additionalName;
  int? age;

  /// Card secondary line: additional name · profession · age (what exists).
  String get details {
    final parts = [
      ?additionalName,
      if (profesi.trim().isNotEmpty) profesi,
      if (age != null && age! > 0) '$age yrs',
    ];
    return parts.join(' · ');
  }

  /// `id_finalis` for contestants that come from the API; null = local only.
  final String? externalId;

  /// `assets/...` (seed) or an http(s) URL; empty = initials fallback.
  String photo;
  String status; // active | inactive

  bool get active => status != 'inactive';
  String get numberLabel => '#${number.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'number': number,
        'name': name,
        'profesi': profesi,
        'photo': photo,
        'status': status,
        'externalId': externalId,
        'additionalName': additionalName,
        'age': age,
      };
  factory ContestantMaster.fromJson(Map<String, dynamic> j) => ContestantMaster(
        id: (j['id'] as num).toInt(),
        number: (j['number'] as num).toInt(),
        name: j['name'] as String? ?? '',
        profesi: j['profesi'] as String? ?? '',
        photo: j['photo'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        externalId: j['externalId'] as String?,
        additionalName: j['additionalName'] as String?,
        age: (j['age'] as num?)?.toInt(),
      );

  /// `GET /judge/admin/contestants` item. [id] is the app's local id (the
  /// store keeps it stable per `id_finalis`).
  factory ContestantMaster.fromApi(Map<String, dynamic> j, {required int id}) => ContestantMaster(
        id: id,
        externalId: '${j['id_finalis']}',
        number: _int(j['nomor_urut'], id),
        name: _text(j['nama_finalis']) ?? 'Finalist',
        profesi: _text(j['profesi']) ?? '',
        photo: _text(j['poster_finalis']) ?? '',
        additionalName: _text(j['nama_tambahan']),
        age: j['usia'] == null ? null : _int(j['usia']),
      );
}

class JudgeMaster {
  JudgeMaster({
    required this.id,
    required this.displayNumber,
    required this.name,
    required this.email,
    required this.phone,
    this.status = 'active',
    this.roles = const [],
  });
  final String id;

  /// [displayNumber] is app-only (the API has no judge number).
  String displayNumber, name, email, phone, status;

  /// API `capabilities[].capability` (e.g. `super_admin`); read-only here.
  final List<String> roles;

  bool get active => status != 'inactive';
  String get label => 'Judge $displayNumber';

  /// `GET /judge/admin/judges` item.
  factory JudgeMaster.fromApi(Map<String, dynamic> j, {required String displayNumber}) => JudgeMaster(
        id: _sid(j['id']),
        displayNumber: displayNumber,
        name: _text(j['name']) ?? 'Unnamed judge',
        email: _text(j['email']) ?? '',
        phone: _text(j['phone']) ?? '',
        status: j['flag_aktif'] == true || _int(j['flag_aktif']) == 1 ? 'active' : 'inactive',
        roles: [
          if (j['capabilities'] is List)
            for (final c in j['capabilities'] as List)
              if (c is Map && _text(c['capability']) != null) _text(c['capability'])!,
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayNumber': displayNumber,
        'name': name,
        'email': email,
        'phone': phone,
        'status': status,
        'roles': roles,
      };
  factory JudgeMaster.fromJson(Map<String, dynamic> j) => JudgeMaster(
        id: _sid(j['id']),
        displayNumber: j['displayNumber'] as String? ?? '',
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        roles: [for (final r in (j['roles'] as List? ?? const [])) '$r'],
      );
}

class JudgeAssignment {
  JudgeAssignment({
    required this.judgeId,
    required this.roundId,
    this.required = true,
    this.status = 'assigned',
    this.excuseReason,
    this.excusedAt,
  });
  final String judgeId, roundId;
  bool required;
  String status; // assigned | excused | removed | unassigned
  String? excuseReason;
  DateTime? excusedAt;

  Map<String, dynamic> toJson() => {
        'judgeId': judgeId,
        'roundId': roundId,
        'required': required,
        'assignmentStatus': status,
        'excuseReason': excuseReason,
        'excusedAt': excusedAt?.toIso8601String(),
      };
  factory JudgeAssignment.fromJson(Map<String, dynamic> j) => JudgeAssignment(
        judgeId: _sid(j['judgeId']),
        roundId: _sid(j['roundId']),
        required: j['required'] as bool? ?? true,
        status: j['assignmentStatus'] as String? ?? 'assigned',
        excuseReason: j['excuseReason'] as String?,
        excusedAt: _date(j['excusedAt']),
      );
}

class AdminCriterion {
  AdminCriterion({
    required this.id,
    required this.roundId,
    required this.name,
    this.parentId,
    this.weight = 0,
    this.minScore = 1,
    this.maxScore = 10,
    this.step = 0.25,
    this.required = true,
    this.isScored = true,
    this.isParent = false,
    this.sequence = 1,
    this.description = '',
  });
  final String id;
  String roundId;
  String name;

  /// API `description` (not edited in the prototype form).
  String description;
  String? parentId;
  double weight, minScore, maxScore, step;
  bool required, isScored, isParent;
  int sequence;

  AdminCriterion copy({String? roundId}) => AdminCriterion(
        id: id,
        roundId: roundId ?? this.roundId,
        name: name,
        parentId: parentId,
        weight: weight,
        minScore: minScore,
        maxScore: maxScore,
        step: step,
        required: required,
        isScored: isScored,
        isParent: isParent,
        sequence: sequence,
        description: description,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roundId': roundId,
        'name': name,
        'description': description,
        'parentId': parentId,
        'weight': weight,
        'minScore': minScore,
        'maxScore': maxScore,
        'step': step,
        'required': required,
        'isScored': isScored,
        'isParent': isParent,
        'sequence': sequence,
      };
  factory AdminCriterion.fromJson(Map<String, dynamic> j) => AdminCriterion(
        id: '${j['id']}',
        roundId: _sid(j['roundId']),
        name: j['name'] as String? ?? '',
        parentId: j['parentId'] as String?,
        weight: _num(j['weight']),
        minScore: _num(j['minScore'], 1),
        maxScore: _num(j['maxScore'], 10),
        step: _num(j['step'], 0.25),
        required: j['required'] as bool? ?? true,
        isScored: j['isScored'] as bool? ?? true,
        isParent: j['isParent'] as bool? ?? false,
        sequence: (j['sequence'] as num?)?.toInt() ?? 1,
        description: j['description'] as String? ?? '',
      );
}

/// Status-only monitoring row (never carries scores).
class MonitoringJudge {
  const MonitoringJudge({
    required this.id,
    required this.number,
    required this.name,
    required this.email,
    required this.phone,
    required this.completed,
    required this.total,
    required this.submissionStatus,
    required this.connection,
    required this.lastSync,
    required this.required,
    required this.assignmentStatus,
    this.submittedAt,
  });
  final String id;
  final String number, name, email, phone;
  final int completed, total;
  final String submissionStatus; // not-started | in-progress | submitted | reopened | resubmitted | excused | removed
  final String connection; // online | syncing | offline
  final String lastSync;
  final bool required;
  final String assignmentStatus;
  final DateTime? submittedAt;
}

class ReadinessItem {
  const ReadinessItem(this.label, this.detail, this.ready);
  final String label, detail;
  final bool ready;
}

class SubmissionSummary {
  const SubmissionSummary(this.total, this.submitted, this.inProgress, this.notStarted);
  final int total, submitted, inProgress, notStarted;
  int get percentage => total == 0 ? 0 : (submitted * 100 / total).round();
}

class Readiness {
  const Readiness({
    required this.contestantsAssigned,
    required this.judgesAssigned,
    required this.requiredJudges,
    required this.optionalJudges,
    required this.requiredSubmitted,
    required this.submissionSummary,
    required this.criteria,
    required this.effectiveScoredWeight,
    required this.weightValid,
    required this.criteriaValid,
    required this.readyToClose,
    required this.items,
  });
  final int contestantsAssigned, judgesAssigned, requiredJudges, optionalJudges, requiredSubmitted;
  final SubmissionSummary submissionSummary;
  final List<AdminCriterion> criteria;
  final double effectiveScoredWeight;
  final bool weightValid, criteriaValid, readyToClose;
  final List<ReadinessItem> items;

  int get scoredCriteriaCount => criteria.where((c) => c.isScored && !c.isParent).length;
}

class ReopenRecord {
  ReopenRecord({
    required this.judgeId,
    required this.roundId,
    required this.reason,
    required this.reopenedAt,
    required this.reopenedBy,
    this.originalSubmittedAt,
    this.resubmittedAt,
  });
  final String judgeId, roundId;
  final String reason, reopenedBy;
  final DateTime reopenedAt;
  final DateTime? originalSubmittedAt;
  DateTime? resubmittedAt;

  Map<String, dynamic> toJson() => {
        'judgeId': judgeId,
        'roundId': roundId,
        'reason': reason,
        'reopenedAt': reopenedAt.toIso8601String(),
        'reopenedBy': reopenedBy,
        'originalSubmittedAt': originalSubmittedAt?.toIso8601String(),
        'resubmittedAt': resubmittedAt?.toIso8601String(),
      };
  factory ReopenRecord.fromJson(Map<String, dynamic> j) => ReopenRecord(
        judgeId: _sid(j['judgeId']),
        roundId: _sid(j['roundId']),
        reason: j['reason'] as String? ?? '',
        reopenedAt: _date(j['reopenedAt']) ?? DateTime.now(),
        reopenedBy: j['reopenedBy'] as String? ?? 'Super Admin',
        originalSubmittedAt: _date(j['originalSubmittedAt']),
        resubmittedAt: _date(j['resubmittedAt']),
      );
}

class AuditEvent {
  const AuditEvent({required this.type, required this.at, required this.actor, this.roundId, this.judgeId, this.reason = ''});
  final String type;
  final String? roundId, judgeId;
  final String reason, actor;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'type': type,
        'roundId': roundId,
        'judgeId': judgeId,
        'reason': reason,
        'at': at.toIso8601String(),
        'actor': actor,
      };
  factory AuditEvent.fromJson(Map<String, dynamic> j) => AuditEvent(
        type: j['type'] as String? ?? '',
        roundId: _sidOrNull(j['roundId']),
        judgeId: _sidOrNull(j['judgeId']),
        reason: j['reason'] as String? ?? '',
        at: _date(j['at']) ?? DateTime.now(),
        actor: j['actor'] as String? ?? 'Super Admin',
      );
}

class JudgeScoreEntry {
  const JudgeScoreEntry({
    required this.judgeId,
    required this.judgeNumber,
    required this.judgeName,
    required this.total,
    required this.included,
    required this.exclusion,
    required this.criteriaScores,
    this.rawTotal,
  });
  final String judgeId;
  final String judgeNumber, judgeName, exclusion;

  /// Weighted total on the 0–100 scale (Σ raw ÷ max × weight).
  final double? total;

  /// Raw total: Σ raw scores of the scored criteria (e.g. 880 of 1000).
  final double? rawTotal;
  final bool included;
  final Map<String, double> criteriaScores;

  Map<String, dynamic> toJson() => {
        'judgeId': judgeId,
        'judgeNumber': judgeNumber,
        'judgeName': judgeName,
        'total': total,
        'included': included,
        'exclusion': exclusion,
        'criteriaScores': criteriaScores,
        'rawTotal': rawTotal,
      };
  factory JudgeScoreEntry.fromJson(Map<String, dynamic> j) => JudgeScoreEntry(
        judgeId: _sid(j['judgeId']),
        judgeNumber: j['judgeNumber'] as String? ?? '',
        judgeName: j['judgeName'] as String? ?? '',
        total: (j['total'] as num?)?.toDouble(),
        included: j['included'] as bool? ?? false,
        exclusion: j['exclusion'] as String? ?? '',
        criteriaScores: {
          for (final e in ((j['criteriaScores'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).toDouble(),
        },
        rawTotal: (j['rawTotal'] as num?)?.toDouble(),
      );
}

class ResultItem {
  ResultItem({
    required this.contestantId,
    required this.number,
    required this.name,
    required this.profesi,
    required this.photo,
    required this.combinedScore,
    required this.eligibleJudgeCount,
    required this.judgeScores,
    this.rank = 0,
    this.tied = false,
    this.rawScore,
  });
  final int contestantId, number, eligibleJudgeCount;
  final String name, profesi, photo;

  /// Final score on the 0–100 scale (server `avg_score`).
  final double combinedScore;

  /// Raw final score: average over the counted judges of their raw totals.
  /// Null until the per-judge detail is loaded (AdminStore.loadRawScores).
  double? rawScore;
  final List<JudgeScoreEntry> judgeScores;
  int rank;
  bool tied;

  String get numberLabel => '#${number.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'contestantId': contestantId,
        'number': number,
        'name': name,
        'profesi': profesi,
        'photo': photo,
        'combinedScore': combinedScore,
        'eligibleJudgeCount': eligibleJudgeCount,
        'judgeScores': [for (final s in judgeScores) s.toJson()],
        'rank': rank,
        'tied': tied,
        'rawScore': rawScore,
      };
  factory ResultItem.fromJson(Map<String, dynamic> j) => ResultItem(
        contestantId: (j['contestantId'] as num).toInt(),
        number: (j['number'] as num).toInt(),
        name: j['name'] as String? ?? '',
        profesi: j['profesi'] as String? ?? '',
        photo: j['photo'] as String? ?? '',
        combinedScore: _num(j['combinedScore']),
        eligibleJudgeCount: (j['eligibleJudgeCount'] as num?)?.toInt() ?? 0,
        judgeScores: [
          for (final s in (j['judgeScores'] as List? ?? const [])) JudgeScoreEntry.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        tied: j['tied'] as bool? ?? false,
        rawScore: (j['rawScore'] as num?)?.toDouble(),
      );
}

class RoundResult {
  const RoundResult.unavailable(this.reason)
      : available = false,
        finalized = false,
        roundId = '',
        eligibleJudgeIds = const [],
        contestantCount = 0,
        items = const [],
        finalizedAt = null,
        finalizedBy = null;

  const RoundResult({
    required this.roundId,
    required this.eligibleJudgeIds,
    required this.contestantCount,
    required this.items,
    this.finalized = false,
    this.finalizedAt,
    this.finalizedBy,
  })  : available = true,
        reason = '';

  final bool available, finalized;
  final String reason;
  final String roundId;
  final int contestantCount;
  final List<String> eligibleJudgeIds;
  final List<ResultItem> items;
  final DateTime? finalizedAt;
  final String? finalizedBy;

  int get eligibleJudgeCount => eligibleJudgeIds.length;
  bool get hasTie => items.any((i) => i.tied);

  Map<String, dynamic> toJson() => {
        'roundId': roundId,
        'eligibleJudgeIds': eligibleJudgeIds,
        'contestantCount': contestantCount,
        'items': [for (final i in items) i.toJson()],
        'finalizedAt': finalizedAt?.toIso8601String(),
        'finalizedBy': finalizedBy,
      };
  factory RoundResult.snapshotFromJson(Map<String, dynamic> j) => RoundResult(
        roundId: _sid(j['roundId']),
        eligibleJudgeIds: [for (final i in (j['eligibleJudgeIds'] as List? ?? const [])) _sid(i)],
        contestantCount: (j['contestantCount'] as num?)?.toInt() ?? 0,
        items: [for (final i in (j['items'] as List? ?? const [])) ResultItem.fromJson(Map<String, dynamic>.from(i as Map))],
        finalized: true,
        finalizedAt: _date(j['finalizedAt']),
        finalizedBy: j['finalizedBy'] as String?,
      );
}

class AdvancementAdjustment {
  const AdvancementAdjustment(this.contestantIds, this.reason, this.at, this.by);
  final List<int> contestantIds;
  final String reason, by;
  final DateTime at;
  Map<String, dynamic> toJson() =>
      {'contestantIds': contestantIds, 'reason': reason, 'at': at.toIso8601String(), 'by': by};
  factory AdvancementAdjustment.fromJson(Map<String, dynamic> j) => AdvancementAdjustment(
        [for (final i in (j['contestantIds'] as List? ?? const [])) (i as num).toInt()],
        j['reason'] as String? ?? '',
        _date(j['at']) ?? DateTime.now(),
        j['by'] as String? ?? '',
      );
}

class Advancement {
  Advancement({
    required this.sourceRoundId,
    required this.targetRoundId,
    required this.selectedContestantIds,
    required this.snapshotId,
    required this.method,
    required this.reason,
    required this.confirmedBy,
    required this.confirmedAt,
    List<AdvancementAdjustment>? adjustments,
  }) : adjustments = adjustments ?? [];
  final String sourceRoundId, targetRoundId;
  final List<int> selectedContestantIds;
  final String snapshotId, method, reason, confirmedBy;
  final DateTime confirmedAt;
  final List<AdvancementAdjustment> adjustments;

  Map<String, dynamic> toJson() => {
        'sourceRoundId': sourceRoundId,
        'targetRoundId': targetRoundId,
        'selectedContestantIds': selectedContestantIds,
        'snapshotId': snapshotId,
        'method': method,
        'reason': reason,
        'confirmedBy': confirmedBy,
        'confirmedAt': confirmedAt.toIso8601String(),
        'adjustments': [for (final a in adjustments) a.toJson()],
      };
  factory Advancement.fromJson(Map<String, dynamic> j) => Advancement(
        sourceRoundId: _sid(j['sourceRoundId']),
        targetRoundId: _sid(j['targetRoundId']),
        selectedContestantIds: [for (final i in (j['selectedContestantIds'] as List? ?? const [])) (i as num).toInt()],
        snapshotId: j['snapshotId'] as String? ?? '',
        method: j['method'] as String? ?? 'top_n',
        reason: j['reason'] as String? ?? '',
        confirmedBy: j['confirmedBy'] as String? ?? '',
        confirmedAt: _date(j['confirmedAt']) ?? DateTime.now(),
        adjustments: [
          for (final a in (j['adjustments'] as List? ?? const []))
            AdvancementAdjustment.fromJson(Map<String, dynamic>.from(a as Map)),
        ],
      );
}

/// Result of a governance / configuration command.
class AdminActionResult {
  const AdminActionResult.ok()
      : ok = true,
        message = null;
  const AdminActionResult.fail(this.message) : ok = false;
  final bool ok;
  final String? message;
}

/// `GET /judge/admin/rounds/{id}/advancement` for a finalized source round.
/// Contestant ids are the app's local ids (mapped from round_contestant ids).
class AdvancementInfo {
  const AdvancementInfo({
    required this.canConfirm,
    this.blockingReason,
    this.targetRoundId,
    this.suggestedIds = const [],
    this.currentIds = const [],
    this.cutoffTie = false,
    this.favoritCandidateId,
    this.targetFavoritEnabled = false,
    this.lastConfirmed,
    this.confirmed = false,
  });

  final bool canConfirm, cutoffTie;

  /// The newest `history[]` entry is a confirmation (not undone by a reset).
  final bool confirmed;

  /// Newest `history[]` entry of type `confirmed`.
  final ({String method, String reason, String actor, DateTime? at})? lastConfirmed;
  final String? blockingReason;
  final String? targetRoundId;
  final List<int> suggestedIds, currentIds;

  /// Favourite-vote contestant the server offers on top of Top N (local id).
  final int? favoritCandidateId;
  final bool targetFavoritEnabled;

  /// [contestantOf] maps a *source-round* round_contestant id; `current`
  /// lists the *target* round's contestants, so those match by `id_finalis`
  /// ([contestantOfFinalis]).
  factory AdvancementInfo.fromApi(
    Map<String, dynamic> j, {
    required int? Function(String roundContestantId) contestantOf,
    required int? Function(String idFinalis) contestantOfFinalis,
  }) {
    int? one(Object? e) {
      if (e is Map) {
        final ext = _text(e['id_finalis']) ?? (e['finalis'] is Map ? _text((e['finalis'] as Map)['id_finalis']) : null);
        if (ext != null) return contestantOfFinalis(ext);
        return contestantOf(_sid(e['round_contestant_id'] ?? e['id']));
      }
      return contestantOf(_sid(e));
    }

    List<int> ids(Object? raw) => [
          if (raw is List)
            for (final e in raw) ?one(e),
        ];
    final target = j['target'];
    // Newest first. `at` mixes UTC ISO (`…T01:41:39Z`) with zone-less WIB
    // (`2026-10-01 08:40:49`), so compare instants, not strings; ties keep
    // the server order (already newest first).
    final raw = [
      for (final h in (j['history'] is List ? j['history'] as List : const []))
        if (h is Map) h,
    ];
    final history = [for (final (i, h) in raw.indexed) (i, h, _serverTime(h['at']))]
      ..sort((a, b) => a.$3 != null && b.$3 != null && a.$3 != b.$3 ? b.$3!.compareTo(a.$3!) : a.$1.compareTo(b.$1));
    final last = history.map((e) => e.$2).where((h) => h['type'] == 'confirmed').firstOrNull;
    return AdvancementInfo(
      confirmed: history.firstOrNull?.$2['type'] == 'confirmed',
      lastConfirmed: last == null
          ? null
          : (
              method: _text(last['method']) ?? 'top_n',
              reason: _text(last['reason']) ?? '',
              actor: _text(last['actor']) ?? '—',
              at: _serverTime(last['at'])?.toLocal(),
            ),
      canConfirm: j['can_confirm'] == true,
      blockingReason: _text(j['blocking_reason']),
      targetRoundId: target is Map ? _sidOrNull(target['id']) : null,
      suggestedIds: ids(j['suggested_contestant_ids']),
      currentIds: ids(j['current']),
      cutoffTie: j['cutoff_tie'] == true,
      favoritCandidateId: switch (j['favorit_candidate']) {
        Map m => contestantOf(_sid(m['round_contestant_id'] ?? m['id'])),
        String s when s.isNotEmpty => contestantOf(s),
        num n => contestantOf('$n'),
        _ => null,
      },
      targetFavoritEnabled: target is Map && target['favorit_promote_enabled'] == true,
    );
  }
}

/// `GET/PATCH /judge/admin/events/{idVote}/settings` (server-side judging rules).
class ServerEventSettings {
  const ServerEventSettings({
    this.scoreMode = 'per_round',
    this.criteriaWeightLockedAcrossRounds = false,
    this.favoritPromoteEnabled = false,
    this.idTheme,
    this.voteIdTheme,
  });
  final String scoreMode;
  final bool criteriaWeightLockedAcrossRounds, favoritPromoteEnabled;

  /// Judge Mode theme chosen by an admin (`id_theme`); null = not chosen,
  /// Judge Mode keeps the KREEN palette.
  final int? idTheme;

  /// The vote's own (web) theme, `vote_id_theme` — read-only, informative.
  final int? voteIdTheme;

  static const _keep = Object();

  /// [idTheme]: pass null to clear the choice; omit to keep it.
  ServerEventSettings copyWith({
    String? scoreMode,
    bool? criteriaWeightLockedAcrossRounds,
    bool? favoritPromoteEnabled,
    Object? idTheme = _keep,
  }) =>
      ServerEventSettings(
        scoreMode: scoreMode ?? this.scoreMode,
        criteriaWeightLockedAcrossRounds: criteriaWeightLockedAcrossRounds ?? this.criteriaWeightLockedAcrossRounds,
        favoritPromoteEnabled: favoritPromoteEnabled ?? this.favoritPromoteEnabled,
        idTheme: identical(idTheme, _keep) ? this.idTheme : idTheme as int?,
        voteIdTheme: voteIdTheme,
      );

  factory ServerEventSettings.fromApi(Map<String, dynamic> j) => ServerEventSettings(
        scoreMode: _text(j['score_mode']) ?? 'per_round',
        criteriaWeightLockedAcrossRounds: j['criteria_weight_locked_across_rounds'] == true,
        favoritPromoteEnabled: j['favorit_promote_enabled'] == true,
        idTheme: j['id_theme'] == null ? null : _int(j['id_theme']),
        voteIdTheme: j['vote_id_theme'] == null ? null : _int(j['vote_id_theme']),
      );

  Map<String, dynamic> toApi() => {
        'score_mode': scoreMode,
        'criteria_weight_locked_across_rounds': criteriaWeightLockedAcrossRounds,
        'favorit_promote_enabled': favoritPromoteEnabled,
        'id_theme': idTheme,
      };

  @override
  bool operator ==(Object other) =>
      other is ServerEventSettings &&
      other.scoreMode == scoreMode &&
      other.criteriaWeightLockedAcrossRounds == criteriaWeightLockedAcrossRounds &&
      other.favoritPromoteEnabled == favoritPromoteEnabled &&
      other.idTheme == idTheme;

  @override
  int get hashCode => Object.hash(scoreMode, criteriaWeightLockedAcrossRounds, favoritPromoteEnabled, idTheme);
}

