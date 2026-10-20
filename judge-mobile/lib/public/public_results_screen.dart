// Public round results (`#/<slug>/round_<n>`, no login) — see
// public_results.dart. Finalized: one card per finalist with each judge's
// total and the final score; tapping a card shows each judge's score per
// criterion. Judges show as "Juri 1", "Juri 2", … (no names). Not finalized yet: "<round> masih berlangsung…".

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/app_scope.dart';
import '../theme/judge_theme.dart';
import '../theme/tokens.dart';
import '../widgets/appearance_toggle.dart';
import '../widgets/common.dart';
import '../widgets/themed_background.dart';
import 'public_results.dart';

class PublicResultsScreen extends StatefulWidget {
  const PublicResultsScreen({super.key, required this.slug, required this.orderNo});
  final String slug;
  final int orderNo;

  @override
  State<PublicResultsScreen> createState() => _PublicResultsScreenState();
}

class _PublicResultsScreenState extends State<PublicResultsScreen> {
  late Future<PublicRoundResult> _future = _load();
  final Set<int> _open = {};

  Future<PublicRoundResult> _load() => PublicResultsApi.instance.roundResult(widget.slug, widget.orderNo);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PublicRoundResult>(
      future: _future,
      builder: (context, snap) {
        final result = snap.data;
        // The event's theme (colours + background picture), like Judge Mode;
        // the default one while loading, on errors and before the result is out.
        final theme = _theme(context, result?.themeId ?? EventTheme.defaultId);
        final light = context.getInheritedWidgetOfExactType<AppearanceScope>()?.notifier?.light ?? false;
        AppColors.palette = theme?.paletteFor(light: light) ?? AppPalette.kreenFor(light: light);

        final Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent));
        } else if (result == null) {
          final error = snap.error;
          final missing = error is ApiException && error.statusCode == 404;
          body = _Notice(
            icon: missing ? Icons.link_off_rounded : Icons.wifi_off_rounded,
            title: missing ? 'Halaman tidak ditemukan' : 'Gagal memuat hasil',
            message: missing
                ? 'Link hasil ini tidak valid. Periksa kembali link yang diberikan panitia.'
                : error is ApiException
                    ? error.message
                    : 'Terjadi kesalahan. Coba lagi beberapa saat lagi.',
            onRetry: missing ? null : () => setState(() => _future = _load()),
          );
        } else if (!result.published) {
          body = _Notice(
            icon: Icons.engineering_rounded,
            eyebrow: result.eventName,
            title: '${result.roundName} masih berlangsung',
            message: 'Juri masih melakukan penilaian. Hasil akan tampil di halaman ini setelah penilaian selesai.',
            onRetry: () => setState(() => _future = _load()),
            retryLabel: 'Muat Ulang',
          );
        } else {
          body = _results(context, result);
        }

        final page = Theme(
          data: buildAppTheme(backgroundPicture: theme != null),
          child: Scaffold(
            body: SafeArea(
              child: Stack(children: [
                Positioned.fill(child: body),
                const Positioned(top: 12, right: 12, child: AppearanceIconButton()),
              ]),
            ),
          ),
        );
        return theme == null ? page : ThemedBackground(url: theme.backgroundUrl, child: page);
      },
    );
  }

  static EventTheme? _theme(BuildContext context, int? id) {
    if (id == null) return null;
    final themes = context.getInheritedWidgetOfExactType<JudgeThemeScope>()?.notifier?.themes ?? EventTheme.builtIn;
    return themes.where((t) => t.id == id).firstOrNull ?? EventTheme.builtIn.where((t) => t.id == id).firstOrNull;
  }

  Widget _results(BuildContext context, PublicRoundResult result) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width <= 620;
    final finalized = result.finalizedAt?.toLocal();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(narrow ? 14 : 20, (width * 0.05).clamp(56.0, 72.0), narrow ? 14 : 20, 64),
      child: MaxWidth(
        maxWidth: 900,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(result.eventName.toUpperCase(),
              style: ts(12, weight: FontWeight.w700, color: AppColors.accentBright, letterSpacingEm: 0.15)),
          const SizedBox(height: 8),
          Text(result.roundName, style: ts((width * 0.05).clamp(28.0, 42.0), weight: FontWeight.w700, letterSpacingEm: -0.03)),
          const SizedBox(height: 8),
          Text(
            'Hasil resmi${finalized == null ? '' : ' · difinalisasi ${_date(finalized)}'}',
            style: ts(15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.accentBright),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Identitas juri dirahasiakan. Ketuk kartu untuk melihat nilai per kriteria.',
                  style: ts(13, color: AppColors.textSecondary, height: 1.45),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          if (result.items.isEmpty)
            Text('Belum ada finalis pada hasil ini.', style: ts(15, color: AppColors.textSecondary))
          else
            for (final (i, item) in result.items.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              _ResultCard(
                item: item,
                criteria: result.criteria,
                narrow: narrow,
                open: _open.contains(i),
                onTap: () => setState(() => _open.contains(i) ? _open.remove(i) : _open.add(i)),
              ),
            ],
        ]),
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}, ${formatClock(d)}';
}

/// Not finalized / not found / failed: icon, title, message, retry.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    this.eyebrow,
    this.onRetry,
    this.retryLabel = 'Coba Lagi',
  });
  final IconData icon;
  final String title, message, retryLabel;
  final String? eyebrow;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 64, 20, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentDeep),
                ),
                child: Icon(icon, size: 44, color: AppColors.accentBright),
              ),
              const SizedBox(height: 22),
              if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                Text(eyebrow!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: ts(12, weight: FontWeight.w700, color: AppColors.accentBright, letterSpacingEm: 0.15)),
                const SizedBox(height: 8),
              ],
              Text(title, textAlign: TextAlign.center, style: ts(24, weight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: ts(15, color: AppColors.textSecondary, height: 1.5)),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                AppButton(label: retryLabel, onTap: onRetry, fontWeight: FontWeight.w700),
              ],
            ]),
          ),
        ),
      );
}

/// One finalist: rank, photo, name, each judge's total and the final score;
/// open → each judge's score per criterion.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.criteria, required this.narrow, required this.open, required this.onTap});
  final PublicResultItem item;
  final List<PublicCriterion> criteria;
  final bool narrow, open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = narrow ? 56.0 : 68.0;
    final finalScore = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(formatScore(item.finalScore), style: ts(narrow ? 20 : 24, weight: FontWeight.w700, tabular: true)),
      Text('Nilai Akhir', style: ts(11, weight: FontWeight.w600, color: AppColors.textSecondary)),
    ]);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(narrow ? 13 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: open ? AppColors.accentDeep : AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              SizedBox(
                width: narrow ? 34 : 48,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${item.rank}',
                      style: ts(narrow ? 22 : 28, weight: FontWeight.w700, color: AppColors.accentBright, tabular: true)),
                  if (item.tied)
                    Text('SERI', style: ts(10, weight: FontWeight.w700, color: AppColors.accentBright, letterSpacingEm: 0.08)),
                ]),
              ),
              Container(
                width: photo,
                height: photo,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderStrong),
                ),
                child: _Photo(item: item),
              ),
              SizedBox(width: narrow ? 12 : 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('#${twoDigits(item.number)}',
                      style: ts(12, weight: FontWeight.w700, color: AppColors.accent, letterSpacingEm: 0.06)),
                  const SizedBox(height: 3),
                  Text(item.name, style: ts(narrow ? 16 : 18, weight: FontWeight.w700, height: 1.25)),
                  if (item.additionalName != null)
                    Text(item.additionalName!, style: ts(13, color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(width: 10),
              finalScore,
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (i, judge) in item.judges.indexed)
                    _Chip(label: publicJudgeLabel(judge, i, item.judges.length), value: formatScore(judge.total)),
                ]),
              ),
              const SizedBox(width: 8),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textSecondary),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open ? _CriteriaTable(item: item, criteria: criteria) : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$label  ', style: ts(12, color: AppColors.textSecondary)),
            TextSpan(text: value, style: ts(13, weight: FontWeight.w700, tabular: true)),
          ]),
        ),
      );
}

/// Criterion × judge scores, with each judge's total as the last row.
class _CriteriaTable extends StatelessWidget {
  const _CriteriaTable({required this.item, required this.criteria});
  final PublicResultItem item;
  final List<PublicCriterion> criteria;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {bool head = false, bool strong = false, bool left = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            text,
            textAlign: left ? TextAlign.left : TextAlign.right,
            style: head
                ? ts(11, weight: FontWeight.w700, color: AppColors.textSecondary, letterSpacingEm: 0.06)
                : ts(13, weight: strong ? FontWeight.w700 : FontWeight.w400, tabular: !left),
          ),
        );
    String score(PublicJudgeScore judge, PublicCriterion c) {
      final v = judge.scores[c.id];
      return v == null ? '–' : formatScore(v);
    }

    final line = BoxDecoration(border: Border(top: BorderSide(color: AppColors.border)));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Table(
          columnWidths: {
            0: const FlexColumnWidth(2.2),
            for (var i = 0; i < item.judges.length; i++) i + 1: const FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [
              cell('KRITERIA', head: true, left: true),
              for (final (i, judge) in item.judges.indexed) cell(publicJudgeLabel(judge, i, item.judges.length).toUpperCase(), head: true),
            ]),
            for (final c in criteria)
              TableRow(decoration: line, children: [
                cell(c.maxPoints == null ? c.name : '${c.name} (maks ${_points(c.maxPoints!)})', left: true),
                for (final judge in item.judges) cell(score(judge, c)),
              ]),
            TableRow(decoration: line, children: [
              cell('Total', strong: true, left: true),
              for (final judge in item.judges) cell(formatScore(judge.total), strong: true),
            ]),
          ],
        ),
      ),
    );
  }

  static String _points(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
}

/// `poster_finalis`, or the gradient + initials fallback (as ContestantPhoto).
class _Photo extends StatelessWidget {
  const _Photo({required this.item});
  final PublicResultItem item;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(ContestantPhoto.initials(item.name),
          style: ts(20, weight: FontWeight.w700, color: const Color.fromRGBO(246, 241, 232, 0.4))),
    );
    final url = item.photoUrl;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ContestantPhoto.fallbackGradient(item.number)),
      child: url == null
          ? fallback
          : Image.network(
              url,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
