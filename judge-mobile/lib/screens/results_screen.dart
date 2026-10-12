// Read-only official Judge Results — port of pages/results.html, fed by
// `GET /judge/rounds/{id}/results`. Visibility is enforced by the server
// (403 "Hasil ronde ini belum ditampilkan oleh admin." until published).
// Shows only rank / contestant / combined score — never other judges'
// individual scores (FR-7).

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../domain/models.dart';
import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.roundId});
  final String roundId;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late Future<ResultSnapshot> _future = JudgeScope.read(context).fetchResults(widget.roundId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResultSnapshot>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent)),
          );
        }
        final error = snap.error;
        if (error is ApiException && error.isNetwork) {
          return _body(context, null, message: error.message, retry: true);
        }
        return _body(context, snap.data, message: error is ApiException ? error.message : null);
      },
    );
  }

  Widget _body(BuildContext context, ResultSnapshot? snapshot, {String? message, bool retry = false}) {
    final store = JudgeScope.of(context);
    final round = store.getRound(widget.roundId);
    final allowed = round != null && snapshot != null;

    final width = MediaQuery.sizeOf(context).width;
    final narrow = width <= 620;
    final titleSize = (width * 0.05).clamp(32.0, 48.0);

    Widget back(String label) => BackLink(
          label,
          onTap: () => JudgeNav.goToMyRounds(context),
        );
    Widget eyebrow() => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(store.eventName(widget.roundId).toUpperCase(),
              style: ts(12, weight: FontWeight.w700, color: AppColors.accentBright, letterSpacingEm: 0.15)),
        );

    final Widget content;
    if (!allowed) {
      content = Padding(
        padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              eyebrow(),
              Text('RESULTS NOT AVAILABLE', style: ts(titleSize, weight: FontWeight.w700, letterSpacingEm: -0.03)),
              const SizedBox(height: 9),
              Text(message ?? 'Official results for this round are not available to you.',
                  style: ts(15, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              if (retry) ...[
                AppButton(
                  label: 'Try Again',
                  onTap: () => setState(() => _future = store.fetchResults(widget.roundId)),
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 8),
              ],
              back('Back to My Rounds'),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: back('My Rounds')),
          eyebrow(),
          Text(round.name, style: ts(15, color: AppColors.textSecondary)),
          const SizedBox(height: 22),
          Text('OFFICIAL RESULTS', style: ts(titleSize, weight: FontWeight.w700, letterSpacingEm: -0.03)),
          const SizedBox(height: 9),
          Text(
            snapshot.isFinal ? 'Finalized ranking and combined scores' : 'Ranking and combined scores',
            style: ts(15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 30),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: snapshot.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Results are published${snapshot.computedAt != null ? ' (computed ${formatClock(snapshot.computedAt!.toLocal())})' : ''}, '
                      'but the ranking list is not included in the response yet.',
                      style: ts(15, color: AppColors.textSecondary, height: 1.5),
                    ),
                  )
                : Column(children: [
                    for (var i = 0; i < snapshot.items.length; i++)
                      _ResultRow(item: snapshot.items[i], narrow: narrow, last: i == snapshot.items.length - 1),
                  ]),
          ),
          const SizedBox(height: 18),
          Text('Official combined score only. Individual judges’ scores remain private.',
              style: ts(12, color: AppColors.textSecondary)),
        ],
      );
    }

    return JudgeBackHandler(
      onBack: () => JudgeNav.goToMyRounds(context),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(narrow ? 14 : 20, (width * 0.06).clamp(36.0, 72.0), narrow ? 14 : 20, 64),
            child: MaxWidth(maxWidth: 900, child: content),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item, required this.narrow, required this.last});
  final ResultItem item;
  final bool narrow;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: narrow ? 82 : 98),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 13 : 24, vertical: narrow ? 13 : 17),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        SizedBox(
          width: narrow ? 36 : 68,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item.rank}',
                style: ts(narrow ? 22 : 28, weight: FontWeight.w700, color: AppColors.accentBright, tabular: true)),
            if (item.tied)
              Text('TIED',
                  style: ts(10, weight: FontWeight.w700, color: AppColors.accentBright, letterSpacingEm: 0.08)),
          ]),
        ),
        SizedBox(width: narrow ? 10 : 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${twoDigits(item.number)}',
                style: ts(12, weight: FontWeight.w700, color: AppColors.accent, letterSpacingEm: 0.06)),
            const SizedBox(height: 4),
            Text(item.name, style: ts(narrow ? 16 : 19, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(item.subtitle, style: ts(13, color: AppColors.textSecondary)),
          ]),
        ),
        SizedBox(width: narrow ? 10 : 18),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(item.combinedScore.toStringAsFixed(2),
              style: ts(narrow ? 18 : 24, weight: FontWeight.w700, tabular: true)),
          Text('/ 100', style: ts(11, weight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}
