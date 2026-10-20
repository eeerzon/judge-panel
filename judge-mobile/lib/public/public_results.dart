// Public results page (no login): one link per round, `#/<slug>/round_<n>`
// (`slug` = the event's `slug`, `n` = the round's `order_no`). Contestants
// check their own scores; judges are anonymous: "Juri 1", "Juri 2", … (as
// numbered by the server, never their names).
//
//   GET /judge/public/events/{slug}/results?round={order_no}   (no token)
//
//   200 → finalized result: data.event { judul_vote, slug, banner },
//         data.round { name, order_no, status, is_final, finalis: [ {
//           rank, avg_score, finalis { nomor_urut, nama_finalis, profesi, poster_finalis },
//           criteria: [ { name, max_points, weight, avg_score,
//                         scores: [ { juri: "Juri 1", raw_score, score } ] } ],
//           juri_totals: [ { juri: "Juri 1", total_score } ] } ] }
//   200 round not finalized yet (e.g. open) → data.state "in_judging",
//         data.event, data.round { name, order_no, status }: no scores.
//   404 "Event tidak ditemukan." → unknown slug.
//   404 "Tidak ada ronde yang tersedia." → the round is still a draft, or
//         the event has no such round.
//   Every 404 shows "Halaman tidak ditemukan".
//
// Per criterion the page shows `score` (weighted: raw / max_points × weight),
// which add up to the judge's `total_score`; the criterion's max is its weight.

import '../api/api_client.dart';
import '../theme/judge_theme.dart';

/// `/<slug>/round_<n>` → (slug, n); anything else → null.
({String slug, int orderNo})? parsePublicResultsRoute(String? name) {
  final match = RegExp(r'^/([A-Za-z0-9_-]+)/round_(\d+)/?$').firstMatch(name ?? '');
  if (match == null || match[1] == 'admin') return null;
  final orderNo = int.parse(match[2]!);
  return orderNo < 1 ? null : (slug: match[1]!, orderNo: orderNo);
}

/// A judge's label: just "Juri" when the round has one judge; otherwise the
/// server's ("Juri 1", "Juri 2", …), or `Juri n` if it is missing.
String publicJudgeLabel(PublicJudgeScore judge, int index, int judgeCount) {
  if (judgeCount == 1) return 'Juri';
  return judge.label.isEmpty ? 'Juri ${index + 1}' : judge.label;
}

String publicResultsRoute(String slug, int orderNo) => '/$slug/round_$orderNo';

/// Where the web build is served (the link the admin shares). Override with
/// `--dart-define=KREEN_PUBLIC_RESULTS_URL=…`.

String publicResultsUrl(String slug, int orderNo) => '$kPublicResultsBaseUrl/#${publicResultsRoute(slug, orderNo)}';

class PublicCriterion {
  const PublicCriterion({required this.id, required this.name, this.maxPoints});
  final String id, name;
  final double? maxPoints;
}

class PublicJudgeScore {
  const PublicJudgeScore({required this.label, required this.total, required this.scores});
  final String label;
  final double total;

  /// Criterion id → raw score (missing = not scored).
  final Map<String, double> scores;
}

class PublicResultItem {
  const PublicResultItem({
    required this.rank,
    required this.tied,
    required this.number,
    required this.name,
    this.additionalName,
    this.photoUrl,
    required this.finalScore,
    required this.judges,
  });
  final int rank, number;
  final bool tied;
  final String name;
  final String? additionalName, photoUrl;
  final double finalScore;
  final List<PublicJudgeScore> judges;
}

class PublicRoundResult {
  const PublicRoundResult({
    required this.eventName,
    this.themeId,
    required this.roundName,
    required this.orderNo,
    required this.status,
    this.finalizedAt,
    this.judges = const [],
    this.criteria = const [],
    this.items = const [],
  });

  final String eventName, roundName, status;
  final int? themeId;
  final int orderNo;
  final DateTime? finalizedAt;
  final List<String> judges;
  final List<PublicCriterion> criteria;
  final List<PublicResultItem> items;

  /// Scores are public only once the round is finalized.
  bool get published => status == 'finalized';

  factory PublicRoundResult.fromJson(Map<String, dynamic> j) {
    final event = _map(j['event']), round = _map(j['round']);
    final rows = _list(round['finalis']).map(_map).toList();
    final ranks = [for (final row in rows) _int(row['rank']) ?? 0];
    // Criteria as listed for the first finalist (the same for everyone).
    final criteria = [
      for (final c in _list(rows.firstOrNull?['criteria']).map(_map))
        PublicCriterion(id: '${c['name']}', name: '${c['name'] ?? ''}', maxPoints: _double(c['weight'])),
    ];
    return PublicRoundResult(
      eventName: '${event['judul_vote'] ?? ''}',
      // No theme in the response yet → the KREEN default.
      themeId: _int(event['id_theme']) ?? EventTheme.defaultId,
      roundName: '${round['name'] ?? ''}',
      orderNo: _int(round['order_no']) ?? 0,
      status: '${round['status'] ?? ''}',
      finalizedAt: DateTime.tryParse('${round['finalized_at'] ?? ''}'),
      judges: [for (final t in _list(rows.firstOrNull?['juri_totals']).map(_map)) '${t['juri'] ?? ''}'],
      criteria: criteria,
      items: [
        for (final (i, row) in rows.indexed)
          () {
            final finalis = _map(row['finalis']);
            final perCriterion = _list(row['criteria']).map(_map).toList();
            return PublicResultItem(
              rank: ranks[i],
              tied: ranks.where((r) => r == ranks[i]).length > 1,
              number: _int(finalis['nomor_urut']) ?? 0,
              name: '${finalis['nama_finalis'] ?? ''}',
              additionalName: _text(finalis['profesi']),
              photoUrl: _text(finalis['poster_finalis']),
              finalScore: _double(row['avg_score']) ?? 0,
              judges: [
                for (final t in _list(row['juri_totals']).map(_map))
                  PublicJudgeScore(
                    label: '${t['juri'] ?? ''}',
                    total: _double(t['total_score']) ?? 0,
                    scores: {
                      for (final c in perCriterion)
                        for (final s in _list(c['scores']).map(_map))
                          if (s['juri'] == t['juri'] && _double(s['score']) != null) '${c['name']}': _double(s['score'])!,
                    },
                  ),
              ],
            );
          }(),
      ],
    );
  }
}

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
List<Object?> _list(Object? v) => v is List ? v : const [];
int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
double? _double(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
String? _text(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v';

abstract class PublicResultsApi {
  /// Set in main() (an ApiClient without the session's token).
  static PublicResultsApi instance = HttpPublicResultsApi(ApiClient());

  /// Throws [ApiException] (404 = unknown event, or no such round / a draft one).
  Future<PublicRoundResult> roundResult(String slug, int orderNo);
}

/// The ApiClient has no token: the page is public.
class HttpPublicResultsApi implements PublicResultsApi {
  HttpPublicResultsApi(this.client);
  final ApiClient client;

  @override
  Future<PublicRoundResult> roundResult(String slug, int orderNo) async {
    return PublicRoundResult.fromJson(
      _map(await client.get('/judge/public/events/${Uri.encodeComponent(slug)}/results?round=$orderNo')),
    );
  }
}
