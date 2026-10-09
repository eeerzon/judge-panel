// One contestant's score sheet — port of pages/scoring.html + scoring.js.
// Range/step per criterion come from `GET .../criteria`; every valid edit is
// saved through JudgeStore's draft + sync queue (`POST .../score-sheet`).
// Read-only once the sheet is submitted/locked or the round is not open.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../navigation/judge_nav.dart';
import '../state/app_scope.dart';
import '../state/judge_store.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/dashed_border.dart';
import '../widgets/judge_chrome.dart';

class ScoringScreen extends StatefulWidget {
  const ScoringScreen({super.key, required this.roundId, required this.contestantId, required this.origin});

  final int roundId;
  final int contestantId;
  final ScoringOrigin origin;

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  late final JudgeStore _store = JudgeScope.read(context);

  Criterion? _editing;
  String? get _editingKey => _editing?.key;
  final _editController = TextEditingController();
  final _editFocus = FocusNode(debugLabel: 'score-edit');
  final Map<String, String> _fieldErrors = {};

  late bool _noteOpen;
  late final TextEditingController _noteController;
  final _noteFocus = FocusNode(debugLabel: 'note');

  int get _roundId => widget.roundId;
  int get _contestantId => widget.contestantId;
  bool get _readOnly => !_store.canJudgeRound(_roundId) || _store.isContestantLocked(_roundId, _contestantId);
  String get _backLabel => widget.origin == ScoringOrigin.review ? 'Review' : 'Contestants';

  @override
  void initState() {
    super.initState();
    final note = _store.getNote(_roundId, _contestantId);
    _noteOpen = note.isNotEmpty;
    _noteController = TextEditingController(text: note);
    _editFocus.addListener(_onEditFocusChange);
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _store.flush(_roundId);
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocus.dispose();
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ score edits

  static double _clampStep(double raw, Criterion c) => c.min + ((raw - c.min) / c.step).round() * c.step;

  static String _fmt(double v, Criterion c) => v.toStringAsFixed(c.decimals);

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  List<Criterion> get _criteria => _store.data(_roundId)?.criteria ?? const [];

  Criterion? _criterionFor(String key) => _criteria.where((c) => c.key == key).firstOrNull;

  double? _value(String key) {
    final c = _criterionFor(key);
    return c == null ? null : _store.getScore(_roundId, _contestantId, c.id);
  }

  void _setScore(String key, double? value) {
    final c = _criterionFor(key);
    if (_readOnly || c == null) return;
    setState(() => _fieldErrors.remove(key));
    _store.setScore(_roundId, _contestantId, c.id, value);
  }

  void _increment(String key) {
    final c = _criterionFor(key);
    if (_readOnly || c == null) return;
    final current = _value(key);
    final next = current == null ? c.min : _clampStep(current + c.step, c);
    if (next > c.max) return;
    _setScore(key, next);
  }

  void _decrement(String key) {
    final c = _criterionFor(key);
    if (_readOnly || c == null) return;
    final current = _value(key);
    if (current == null) return; // nothing below "empty"
    final next = _clampStep(current - c.step, c);
    if (next < c.min) return;
    _setScore(key, next);
  }

  void _openEdit(String key) {
    final c = _criterionFor(key);
    if (_readOnly || c == null) return;
    final current = _value(key);
    setState(() {
      _editing = c;
      _fieldErrors.remove(key);
      _editController.text = current == null ? '' : _fmt(current, c);
      _editController.selection = TextSelection(baseOffset: 0, extentOffset: _editController.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _editFocus.requestFocus());
  }

  void _onEditFocusChange() {
    final key = _editingKey;
    if (!_editFocus.hasFocus && key != null) _commitEdit(key, _editController.text);
  }

  /// FR-3 validation, in order, with a specific message per case. Never
  /// silent-rounds: an invalid entry stays in the field so the judge sees
  /// exactly what to fix. An empty field clears the score (back to null).
  void _commitEdit(String key, String rawValue) {
    final c = _criterionFor(key);
    if (c == null) return;
    final raw = rawValue.trim();
    if (raw.isEmpty) {
      setState(() => _editing = null);
      _setScore(key, null);
      return;
    }
    final num = double.tryParse(raw);
    String? error;
    if (num == null || num.isNaN) {
      error = 'Enter a number.';
    } else if (num < c.min) {
      error = 'Minimum score is ${_fmtNum(c.min)}.';
    } else if (num > c.max) {
      error = 'Maximum score is ${_fmtNum(c.max)}.';
    } else {
      final steps = (num - c.min) / c.step;
      if ((steps.round() - steps).abs() > 0.001) error = 'Use increments of ${_fmtNum(c.step)}.';
    }
    if (error != null) {
      setState(() => _fieldErrors[key] = error!);
      // Refocus with the cursor at the end of what they typed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _editingKey != key) return;
        _editController.selection = TextSelection.collapsed(offset: _editController.text.length);
        _editFocus.requestFocus();
      });
      return;
    }
    setState(() => _editing = null);
    _setScore(key, _clampStep(num!, c));
  }

  void _cancelEdit() {
    setState(() => _editing = null);
    _editFocus.unfocus();
  }

  /// Commits a pending manual edit; returns false if it is invalid and the
  /// judge must fix it before leaving this contestant.
  bool _validateBeforeLeaving() {
    final key = _editingKey;
    if (key != null) _commitEdit(key, _editController.text);
    return !(_editingKey != null && _fieldErrors[_editingKey] != null);
  }

  // ------------------------------------------------------------ navigation

  List<Contestant> get _contestants => _store.contestantsOf(_roundId);

  void _goBack() {
    if (widget.origin == ScoringOrigin.review) {
      JudgeNav.goToReview(context, _roundId);
    } else {
      JudgeNav.goToContestants(context, _roundId);
    }
  }

  void _prev() {
    if (!_validateBeforeLeaving()) return;
    final position = _contestants.indexWhere((c) => c.id == _contestantId);
    if (position > 0) JudgeNav.goToScoring(context, _roundId, _contestants[position - 1].id, widget.origin);
  }

  void _next() {
    if (!_validateBeforeLeaving()) return;
    if (!_readOnly) _store.flush(_roundId);
    final list = _contestants;
    final position = list.indexWhere((c) => c.id == _contestantId);
    if (position < list.length - 1) {
      JudgeNav.goToScoring(context, _roundId, list[position + 1].id, widget.origin);
    } else {
      _goBack();
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final store = JudgeScope.of(context);
    final round = store.getRound(_roundId)!;
    final sections = store.data(_roundId)?.sections ?? const <ScoringSection>[];
    final contestant = store.getContestant(_roundId, _contestantId)!;
    final list = _contestants;
    final position = list.indexWhere((c) => c.id == _contestantId);
    final isLast = position == list.length - 1;
    final readOnly = _readOnly;
    final submitted = store.isContestantLocked(_roundId, _contestantId);

    final nextLabel = readOnly
        ? (isLast ? 'Back to $_backLabel →' : 'Next →')
        : (isLast ? 'Save & Back to $_backLabel →' : 'Save & Next →');

    return JudgeBackHandler(
      onBack: _goBack,
      child: Scaffold(
        body: SafeArea(
          child: JudgeChrome(
            roundId: _roundId,
            child: LayoutBuilder(builder: (context, constraints) {
              final portrait = constraints.maxHeight > constraints.maxWidth;
              final shellWidth = constraints.maxWidth.clamp(0.0, AppLayout.scoringShellMaxWidth);
              final panelWidth = (shellWidth * 0.32).clamp(300.0, 440.0);
              final hPad = portrait ? 20.0 : 32.0;

              final identity = _IdentityPanel(
                contestant: contestant,
                portrait: portrait,
                progress: _progressChip(store, submitted),
                total: store.calculateContestantTotal(_roundId, _contestantId),
              );
              final sheet = _buildSheet(store, sections, readOnly: readOnly, submitted: submitted);

              final Widget body;
              if (portrait) {
                body = SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                        child: identity,
                      ),
                      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), child: sheet),
                    ],
                  ),
                );
              } else {
                final sidePad = (constraints.maxWidth * 0.05).clamp(32.0, 72.0);
                body = MaxWidth(
                  maxWidth: AppLayout.scoringShellMaxWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: panelWidth,
                        decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                          child: identity,
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(sidePad, 28, sidePad, 40),
                          child: Center(
                            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: sheet),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    hPad: hPad,
                    vPad: portrait ? 16 : 18,
                    backLabel: '← $_backLabel',
                    onBack: _goBack,
                    roundName: round.name,
                    position: '${twoDigits(position + 1)} / ${list.length}',
                  ),
                  Expanded(child: body),
                  _Footer(
                    portrait: portrait,
                    hPad: hPad,
                    slotWidth: panelWidth,
                    onPrev: position == 0 ? null : _prev,
                    saveStatus: _saveStatusText(),
                    nextLabel: nextLabel,
                    onNext: _next,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _progressChip(JudgeStore store, bool submitted) {
    final info = store.getContestantStatus(_roundId, _contestantId);
    final complete = submitted || info.status == ScoreStatus.scored;
    final text = submitted
        ? 'Submitted'
        : (complete ? '✓ Complete' : '${info.scoredCount} of ${info.total} criteria scored');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: complete ? AppColors.statusScoredFill : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: complete ? AppColors.statusScoredFillBorder : AppColors.border),
        boxShadow: complete ? const [BoxShadow(color: AppColors.statusScoredGlow, blurRadius: 10)] : null,
      ),
      child: Text(
        text,
        style: ts(14,
            weight: complete ? FontWeight.w700 : FontWeight.w600,
            color: complete ? AppColors.statusScoredText : AppColors.textSecondary),
      ),
    );
  }

  Widget _saveStatusText() {
    final indicator = _readOnly && !_store.isContestantLocked(_roundId, _contestantId)
        ? SaveIndicator.locked
        : _store.saveIndicator(_roundId, _contestantId);
    final (String text, Color color) = switch (indicator) {
      SaveIndicator.saved => ('Saved ✓', AppColors.statusScoredIcon),
      SaveIndicator.saving => ('Saving…', AppColors.textSecondary),
      SaveIndicator.savedOnDevice => ('Saved on device', AppColors.statusDraftColor),
      SaveIndicator.error => ('Unable to save', AppColors.statusErrorColor),
      SaveIndicator.locked => ('Locked', AppColors.statusScoredIcon),
    };
    final message = indicator == SaveIndicator.error ? _store.syncMessage : null;
    return Semantics(
      liveRegion: true,
      child: Tooltip(
        message: message ?? '',
        child: Text(text, style: ts(15, weight: FontWeight.w600, color: color, tabular: true)),
      ),
    );
  }

  Widget _buildSheet(JudgeStore store, List<ScoringSection> sections, {required bool readOnly, required bool submitted}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (readOnly && submitted) const _LockBanner(),
        if (!readOnly && store.saveIndicator(_roundId, _contestantId) == SaveIndicator.error && store.syncMessage != null)
          _SyncErrorBanner(message: store.syncMessage!, onRetry: () => store.flush(_roundId)),
        for (final section in sections) _section(section, readOnly),
        _noteBlock(store, readOnly),
      ],
    );
  }

  Widget _section(ScoringSection section, bool readOnly) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(section.heading.toUpperCase(),
                      style: ts(15, weight: FontWeight.w700, letterSpacingEm: 0.14)),
                ),
                const SizedBox(width: 12),
                Text('${_fmtNum(section.weight)}%',
                    style: ts(14, weight: FontWeight.w600, color: AppColors.accentBright, tabular: true)),
              ],
            ),
          ),
          for (var i = 0; i < section.criteria.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == section.criteria.length - 1 ? 0 : 26),
              child: _criterion(section.criteria[i], readOnly),
            ),
        ],
      ),
    );
  }

  Widget _criterion(Criterion criterion, bool readOnly) {
    final key = criterion.key;
    final value = _value(key);
    final error = _fieldErrors[key];
    final editing = !readOnly && _editingKey == key;
    final canDecrement = !readOnly && value != null && value > criterion.min;
    final canIncrement = !readOnly && (value == null || value < criterion.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!criterion.standalone)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(criterion.label, style: ts(16, weight: FontWeight.w600))),
                const SizedBox(width: 12),
                Text('${_fmtNum(criterion.weight)}%', style: ts(13, color: AppColors.textSecondary, tabular: true)),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepperButton(
              symbol: '−',
              semanticLabel: 'Decrease ${criterion.label} score',
              onTap: canDecrement ? () => _decrement(key) : null,
            ),
            const SizedBox(width: 24),
            editing ? _editField(key, error != null) : _valueDisplay(criterion, value, readOnly),
            const SizedBox(width: 24),
            _StepperButton(
              symbol: '+',
              semanticLabel: 'Increase ${criterion.label} score',
              onTap: canIncrement ? () => _increment(key) : null,
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              liveRegion: true,
              child: Text(error,
                  textAlign: TextAlign.center,
                  style: ts(14, weight: FontWeight.w500, color: AppColors.statusErrorColor)),
            ),
          ),
        if (criterion.quickScore != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('Quick score', style: ts(13, color: AppColors.textSecondary)),
                ),
                for (final v in criterion.quickScore!)
                  _QuickScoreButton(
                    value: v,
                    selected: value == v,
                    onTap: readOnly ? null : () => _setScore(key, v),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _valueDisplay(Criterion criterion, double? value, bool readOnly) {
    final text = Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.transparent),
      ),
      child: Text(
        value == null ? '—' : _fmt(value, criterion),
        style: ts(32,
            weight: value == null ? FontWeight.w500 : FontWeight.w700,
            color: value == null ? AppColors.textSecondary : AppColors.textPrimary,
            tabular: true),
      ),
    );
    if (readOnly) return text;
    return Semantics(
      button: true,
      label: 'Edit ${criterion.label} score, current value ${value == null ? 'not set' : _fmt(value, criterion)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openEdit(criterion.key),
        child: ExcludeSemantics(child: text),
      ),
    );
  }

  Widget _editField(String key, bool hasError) {
    final borderColor = hasError ? AppColors.statusErrorColor : AppColors.accent;
    final ring = hasError ? const Color.fromRGBO(224, 137, 122, 0.22) : AppColors.accentSoft;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelEdit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: ring, spreadRadius: 3)],
        ),
        child: TextField(
          controller: _editController,
          focusNode: _editFocus,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          style: ts(28, weight: FontWeight.w700, tabular: true),
          onSubmitted: (_) => _editFocus.unfocus(),
          onTapOutside: (_) => _editFocus.unfocus(),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _noteBlock(JudgeStore store, bool readOnly) {
    final note = store.getNote(_roundId, _contestantId);
    Widget area({required bool editable}) => TextField(
          controller: _noteController,
          focusNode: editable ? _noteFocus : null,
          readOnly: !editable,
          minLines: 3,
          maxLines: 8,
          style: ts(15),
          onChanged: editable ? (text) => store.setNote(_roundId, _contestantId, text) : null,
          onTapOutside: (_) => _noteFocus.unfocus(),
          decoration: InputDecoration(
            hintText: editable ? 'Optional note about this contestant…' : null,
            hintStyle: ts(15, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: editable ? AppColors.accent : AppColors.border),
            ),
          ),
        );

    if (readOnly) {
      if (note.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Note', style: ts(13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          area(editable: false),
        ],
      );
    }
    if (!_noteOpen) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Pressable(
          pressedScale: 0.98,
          onTap: () {
            setState(() => _noteOpen = true);
            WidgetsBinding.instance.addPostFrameCallback((_) => _noteFocus.requestFocus());
          },
          child: DashedBorder(
            color: AppColors.borderStrong,
            radius: 10,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              child: Text('+ Add note', style: ts(15, weight: FontWeight.w500, color: AppColors.textSecondary)),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Note (optional)', style: ts(13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        area(editable: true),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hPad,
    required this.vPad,
    required this.backLabel,
    required this.onBack,
    required this.roundName,
    required this.position,
  });

  final double hPad;
  final double vPad;
  final String backLabel;
  final VoidCallback onBack;
  final String roundName;
  final String position;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: vPad),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: MaxWidth(
        maxWidth: AppLayout.scoringShellMaxWidth,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppButton(
                label: backLabel,
                onTap: onBack,
                variant: AppButtonVariant.outline,
                fontWeight: FontWeight.w500,
              ),
              const SizedBox(width: 16),
              RoundLabel(roundName),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 70),
                child: Text(position,
                    textAlign: TextAlign.right,
                    style: ts(15, weight: FontWeight.w600, color: AppColors.textSecondary, tabular: true)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({required this.contestant, required this.portrait, required this.progress, required this.total});

  final Contestant contestant;
  final bool portrait;
  final Widget progress;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final photo = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: AspectRatio(aspectRatio: 3 / 4, child: ContestantPhoto(contestant: contestant, initialsSize: 48)),
    );

    final totalBlock = Container(
      padding: EdgeInsets.only(top: portrait ? 12 : 18),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Flex(
        direction: portrait ? Axis.horizontal : Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: portrait ? CrossAxisAlignment.baseline : CrossAxisAlignment.center,
        textBaseline: TextBaseline.alphabetic,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text('TOTAL SCORE',
              style: ts(12, weight: FontWeight.w600, color: AppColors.textSecondary, letterSpacingEm: 0.16)),
          SizedBox(width: portrait ? 10 : 0, height: portrait ? 0 : 2),
          Text(
            total == null ? '—' : total!.toStringAsFixed(2),
            style: ts(36,
                weight: total == null ? FontWeight.w500 : FontWeight.w700,
                color: total == null ? AppColors.textSecondary : AppColors.accentBright,
                height: 1.15,
                tabular: true),
          ),
          SizedBox(width: portrait ? 10 : 0, height: portrait ? 0 : 2),
          Text('/ 100', style: ts(13, weight: FontWeight.w500, color: AppColors.textSecondary)),
        ],
      ),
    );

    if (portrait) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 112, child: photo),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contestant.numberLabel,
                  style: ts(26, weight: FontWeight.w700, color: AppColors.accent, tabular: true)),
              const SizedBox(height: 2),
              Text(contestant.name, style: ts(18, weight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 2),
              Text(contestant.subtitle, style: ts(14, color: AppColors.textSecondary)),
            ],
          ),
          progress,
          Padding(padding: const EdgeInsets.only(top: 4), child: totalBlock),
        ],
      );
    }

    return Column(
      children: [
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: photo),
        const SizedBox(height: 16 + 6),
        Text(contestant.numberLabel, style: ts(34, weight: FontWeight.w700, color: AppColors.accent, tabular: true)),
        const SizedBox(height: 6),
        Text(contestant.name,
            textAlign: TextAlign.center, style: ts(24, weight: FontWeight.w600, height: 1.3)),
        const SizedBox(height: 6),
        Text(contestant.subtitle, textAlign: TextAlign.center, style: ts(16, color: AppColors.textSecondary)),
        const SizedBox(height: 6 + 16),
        progress,
        const SizedBox(height: 6 + 20),
        totalBlock,
      ],
    );
  }
}

/// `.score-btn` — 56×56, radius 14; disabled at 0.32 opacity.
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.symbol, required this.semanticLabel, required this.onTap});
  final String symbol;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.32 : 1,
      child: Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ExcludeSemantics(child: Text(symbol, style: ts(26, weight: FontWeight.w600, height: 1))),
        ),
      ),
    );
  }
}

class _QuickScoreButton extends StatelessWidget {
  const _QuickScoreButton({required this.value, required this.selected, required this.onTap});
  final double value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: Semantics(
        selected: selected,
        child: Pressable(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 48),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentSoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? AppColors.accent : AppColors.border),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(value.toInt().toString(), style: ts(15, weight: FontWeight.w600, tabular: true)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockBanner extends StatelessWidget {
  const _LockBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.statusScoredFill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text('Submitted', style: ts(14, weight: FontWeight.w700, color: AppColors.statusScoredText)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Your scores have been submitted and can no longer be edited.',
                style: ts(14, weight: FontWeight.w600, color: AppColors.statusScoredText)),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.portrait,
    required this.hPad,
    required this.slotWidth,
    required this.onPrev,
    required this.saveStatus,
    required this.nextLabel,
    required this.onNext,
  });

  final bool portrait;
  final double hPad;
  final double slotWidth;
  final VoidCallback? onPrev;
  final Widget saveStatus;
  final String nextLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final btnPad = EdgeInsets.symmetric(horizontal: portrait ? 16 : 26);
    final prev = AppButton(
      label: '← Previous',
      onTap: onPrev,
      variant: AppButtonVariant.neutral,
      height: 56,
      radius: 12,
      fontSize: portrait ? 15 : 16,
      padding: btnPad,
    );
    final next = AppButton(
      label: nextLabel,
      onTap: onNext,
      height: 56,
      radius: 12,
      fontSize: portrait ? 15 : 16,
      padding: btnPad,
    );
    return Container(
      padding: EdgeInsets.symmetric(vertical: portrait ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: MaxWidth(
        maxWidth: AppLayout.scoringShellMaxWidth,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: portrait
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [prev, Flexible(child: saveStatus), next],
                )
              : Row(
                  children: [
                    SizedBox(width: slotWidth - hPad, child: Align(alignment: Alignment.centerLeft, child: prev)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [saveStatus, const SizedBox(width: 16), Flexible(child: next)],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(224, 137, 122, 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(224, 137, 122, 0.45)),
      ),
      child: Row(children: [
        Expanded(
          child: Text('Unable to save: $message',
              style: ts(14, weight: FontWeight.w500, color: AppColors.statusErrorColor, height: 1.4)),
        ),
        const SizedBox(width: 12),
        AppButton(label: 'Retry', onTap: onRetry, variant: AppButtonVariant.outline, fontSize: 14),
      ]),
    );
  }
}
