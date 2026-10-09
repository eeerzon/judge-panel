// admin/settings.html — event-level defaults with dirty state, validation and
// reset (admin-settings.js). Fixed policies are shown read-only, as in HTML.

import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/judge_theme.dart';
import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_scope.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_ui.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _State();
}

class _State extends State<AdminSettingsScreen> {
  final _name = TextEditingController();
  final _year = TextEditingController();
  final _short = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _step = TextEditingController();
  late bool _criterionRequired, _judgeRequired, _visibility;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fill(AdminScope.read(context).eventSettings);
    _loadThemes();
  }

  /// Live theme list; the built-in copy stays when it cannot be loaded.
  Future<void> _loadThemes() async {
    final raw = await AdminScope.read(context).fetchThemes();
    if (!mounted || raw == null) return;
    JudgeThemeScope.read(context).setThemes([for (final j in raw) ?EventTheme.fromApi(j)]);
  }

  @override
  void dispose() {
    for (final c in [_name, _year, _short, _min, _max, _step]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(EventSettings s) {
    _name.text = s.eventName;
    _year.text = s.eventYear;
    _short.text = s.shortName;
    _min.text = pct(s.minScore);
    _max.text = pct(s.maxScore);
    _step.text = pct(s.step);
    _criterionRequired = s.defaultCriterionRequired;
    _judgeRequired = s.defaultJudgeAssignmentRequired;
    _visibility = s.resultVisibilityAfterFinalization;
    _error = null;
  }

  EventSettings get _current => EventSettings(
        eventName: _name.text.trim(),
        eventYear: _year.text.trim(),
        shortName: _short.text.trim(),
        minScore: double.tryParse(_min.text.trim()) ?? double.nan,
        maxScore: double.tryParse(_max.text.trim()) ?? double.nan,
        step: double.tryParse(_step.text.trim()) ?? double.nan,
        defaultCriterionRequired: _criterionRequired,
        defaultJudgeAssignmentRequired: _judgeRequired,
        resultVisibilityAfterFinalization: _visibility,
      );

  void _save() {
    final v = _current;
    if (v.eventName.isEmpty || v.shortName.isEmpty || !RegExp(r'^\d{4}$').hasMatch(v.eventYear)) {
      setState(() => _error = 'Enter an event name, a short name, and a four-digit event year.');
      return;
    }
    if (!v.minScore.isFinite ||
        !v.maxScore.isFinite ||
        !v.step.isFinite ||
        v.maxScore <= v.minScore ||
        v.step <= 0 ||
        v.step > v.maxScore - v.minScore) {
      setState(() => _error = 'Enter a score scale with Max greater than Min and a positive step within that range.');
      return;
    }
    final admin = AdminScope.read(context);
    if (!admin.setEventSettings(v)) {
      setState(() => _error = 'Settings could not be saved on this device.');
      return;
    }
    setState(() => _fill(admin.eventSettings));
  }

  void _reset() {
    showAdminModal(
      context,
      title: 'Reset Event Settings?',
      body: 'Reset only Event Settings to their defaults? Contestants, rounds, scores, results, and advancement will stay unchanged.',
      confirmLabel: 'Reset Settings',
      confirmVariant: AdminBtnVariant.danger,
      onConfirm: (_) {
        final admin = AdminScope.read(context);
        admin.setEventSettings(const EventSettings());
        setState(() => _fill(admin.eventSettings));
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = AdminScope.of(context).eventSettings;
    final dirty = _current != saved;
    final tiny = AdminLayout.tiny(context);
    void changed(_) => setState(() => _error = null);

    Widget field(String label, TextEditingController c, {TextInputType? type}) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: AdminFormField(label: label, child: AdminTextField(controller: c, keyboardType: type, onChanged: changed)),
        );
    Widget toggleRow(String label, String help, bool value, ValueChanged<bool> onChanged) {
      final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: ts(14, weight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(help, style: ts(12, color: AppColors.textSecondary, height: 1.45)),
      ]);
      final control = Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 30,
          child: Text(value ? 'ON' : 'OFF',
              style: ts(11, weight: FontWeight.w800, color: AppColors.textSecondary, letterSpacingEm: 0.05)),
        ),
        const SizedBox(width: 10),
        AdminToggle(on: value, semanticLabel: label, onChanged: (v) => setState(() => onChanged(v))),
      ]);
      return _Divided(
        child: tiny
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 10), control])
            : Row(children: [Expanded(child: text), const SizedBox(width: 16), control]),
      );
    }

    Widget policy(String title, String help, String state) {
      final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: ts(14, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(help, style: ts(12, color: AppColors.textSecondary, height: 1.45)),
      ]);
      final s = Text(state, style: ts(12, weight: FontWeight.w700, color: AppColors.textSecondary));
      return _Divided(
        child: tiny
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 10), s])
            : Row(children: [Expanded(child: text), const SizedBox(width: 16), s]),
      );
    }

    return AdminShell(activeNav: 'settings', children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const AdminPageHeader(title: 'Settings', description: 'Event-level defaults and preferences for judging operations.'),
          AdminWarning(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Event Settings', style: ts(13, weight: FontWeight.w800, color: AppColors.statusDraftColor)),
              const TextSpan(text: ' define global defaults and preferences. '),
              TextSpan(text: 'Round Settings', style: ts(13, weight: FontWeight.w800, color: AppColors.statusDraftColor)),
              const TextSpan(
                  text:
                      ' belong to a specific round, such as Preliminary, Top 10, or Final. Contestants, judges, criteria, advancement, and result snapshots remain in their round workspaces.'),
            ])),
          ),
          const SizedBox(height: 18),
          _SettingsPanel(
            eyebrow: '01 / Event',
            title: 'Event Identity',
            description: 'Display information for this judging event. Prototype values only.',
            children: [
              field('Event Name', _name),
              field('Event Year', _year, type: TextInputType.number),
              field('Short Name', _short),
            ],
          ),
          _SettingsPanel(
            eyebrow: '02 / Scoring',
            title: 'Judging Defaults',
            description:
                'Changes apply to new judging configuration only. Existing round criteria and judge assignments are not rewritten.',
            children: [
              field('Min Score', _min, type: const TextInputType.numberWithOptions(decimal: true)),
              field('Max Score', _max, type: const TextInputType.numberWithOptions(decimal: true)),
              field('Default Step', _step, type: const TextInputType.numberWithOptions(decimal: true)),
              toggleRow('Default Criterion Required', 'Preselect Required when adding a criterion to a Draft round.',
                  _criterionRequired, (v) => _criterionRequired = v),
              toggleRow('Default Judge Assignment Required', 'New judge assignments in Draft rounds begin as required.',
                  _judgeRequired, (v) => _judgeRequired = v),
            ],
          ),
          _SettingsPanel(
            eyebrow: '03 / Results',
            title: 'Result Defaults',
            description: 'The default below applies only when a round is newly finalized. Existing per-round visibility remains unchanged.',
            children: [
              toggleRow(
                'Judge Result Visibility After Finalization',
                'Initial visibility for newly finalized rounds. Off means an Admin must enable it manually. Judges never see another judge’s scores.',
                _visibility,
                (v) => _visibility = v,
              ),
            ],
          ),
          _SettingsPanel(
            eyebrow: '04 / Governance',
            title: 'Operational Preferences',
            description: 'These are enforced prototype policies, shown for clarity rather than offered as unsafe switches.',
            children: [
              policy('Require Reason for Reopen Submission', 'Admin must provide a reason before a submitted score sheet is reopened.', 'On · Fixed'),
              policy('Require Reason for Excuse Judge', 'An excused required judge needs a recorded reason.', 'On · Fixed'),
              policy('Require Tie Acknowledgement Before Finalize',
                  'Unresolved ties require acknowledgement before results can be finalized.', 'On · Fixed'),
            ],
          ),
          _SettingsPanel(
            eyebrow: '05 / Judge mode',
            title: 'Judge Experience',
            description: 'Current Judge Mode behavior. These controls are read-only in this prototype.',
            children: [
              policy('Show Save Status', 'Judges can see whether their work has been saved.', 'On · Fixed'),
              policy('Allow Judge Notes', 'Judges may keep notes within their scoring flow.', 'On · Fixed'),
              policy('Show Total Score During Scoring', 'Only the judge’s own score is available while a round is open.', 'On · Fixed'),
              policy('Show Round Results After Admin Enables', 'Results require finalized status and Admin-controlled visibility.',
                  'On · Fixed'),
            ],
          ),
          const _JudgeThemePanel(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_error!, style: ts(12, weight: FontWeight.w600, color: AppColors.statusErrorColor)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 32),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(dirty ? 'Unsaved changes' : 'All changes saved',
                    style: ts(13, weight: FontWeight.w600, color: dirty ? AppColors.statusDraftColor : AppColors.success)),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  AdminBtn('Cancel Changes', onTap: dirty ? () => setState(() => _fill(saved)) : null),
                  AdminBtn('Save Settings', variant: AdminBtnVariant.primary, onTap: dirty ? _save : null),
                ]),
              ],
            ),
          ),
          AdminPanel(
            padding: EdgeInsets.all(tiny ? 18 : 24),
            borderColor: const Color.fromRGBO(224, 137, 122, 0.45),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AdminEyebrow('Prototype only', color: AppColors.statusErrorColor),
              const SizedBox(height: 7),
              Text('Danger Zone', style: ts(19, weight: FontWeight.w700, height: 1.3)),
              const SizedBox(height: 7),
              Text('Restore event Settings to their defaults. Contestants, scores, rounds, results, and advancement will not be reset.',
                  style: ts(13, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              AdminBtn('Reset Settings', variant: AdminBtnVariant.danger, onTap: _reset),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.eyebrow, required this.title, required this.description, required this.children});
  final String eyebrow, title, description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AdminPanel(
          padding: EdgeInsets.all(AdminLayout.tiny(context) ? 18 : 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AdminEyebrow(eyebrow),
            const SizedBox(height: 7),
            Text(title, style: ts(19, weight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 7),
            Text(description, style: ts(13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            ...children,
          ]),
        ),
      );
}

class _Divided extends StatelessWidget {
  const _Divided({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        alignment: Alignment.centerLeft,
        child: child,
      );
}

/// 06 / Interface — Judge Mode theme of this event (`id_theme` in the
/// event settings). Saved to the server at once; every judge tablet gets it
/// with `/judge/rounds`. Admin Mode keeps the KREEN palette.
class _JudgeThemePanel extends StatefulWidget {
  const _JudgeThemePanel();

  @override
  State<_JudgeThemePanel> createState() => _JudgeThemePanelState();
}

class _JudgeThemePanelState extends State<_JudgeThemePanel> {
  int? _saving; // theme id being saved
  String? _error;

  Future<void> _choose(EventTheme theme) async {
    final admin = AdminScope.read(context);
    final themes = JudgeThemeScope.read(context);
    final current = admin.serverSettings, eventId = admin.event?.id;
    if (current == null || eventId == null || _saving != null) return;
    if ((current.idTheme ?? EventTheme.kreenId) == theme.id) return;
    setState(() {
      _saving = theme.id;
      _error = null;
    });
    final error = await admin.saveServerSettings(current.copyWith(idTheme: theme.id));
    if (!mounted) return;
    // This device switches at once, even before Judge Mode reloads its rounds.
    if (error == null) themes.remember(eventId, theme.isKreen ? null : theme);
    setState(() {
      _saving = null;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = JudgeThemeScope.of(context);
    final settings = AdminScope.of(context).serverSettings;
    // Nothing chosen yet = the KREEN default (id 0).
    final selected = settings?.idTheme ?? EventTheme.kreenId;
    return _SettingsPanel(
      eyebrow: '06 / Interface',
      title: 'Judge Mode Theme',
      description: 'Background and accent colours of Judge Mode on every judge tablet for this event. '
          'Status colours (Scored, Draft, errors) never change, and Admin Mode keeps the KREEN theme.',
      children: [
        if (settings == null)
          Text('Theme settings could not be loaded. Refresh the event and try again.',
              style: ts(13, color: AppColors.textSecondary))
        else
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final t in store.themes)
              _ThemeCard(
                name: t.name,
                caption: _saving == t.id
                    ? 'Saving…'
                    : t.isKreen
                        ? 'Default'
                        : null,
                palette: t.palette,
                selected: selected == t.id,
                onTap: _saving != null ? null : () => _choose(t),
              ),
          ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: ts(12, weight: FontWeight.w600, color: AppColors.statusErrorColor)),
          ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.name, this.caption, required this.palette, required this.selected, this.onTap});
  final String name;
  final String? caption;
  final AppPalette palette;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Judge Mode theme $name',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.accentBright : AppColors.border, width: selected ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Mini Judge Mode preview in the theme's own palette.
            Container(
              height: 78,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: p.bgBase, borderRadius: BorderRadius.circular(9)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ROUND 1', style: ts(9, weight: FontWeight.w700, color: p.accentBright, letterSpacingEm: 0.2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.surfaceRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.accent),
                  ),
                  child: Row(children: [
                    Expanded(child: Text('Score', style: ts(10, color: p.textSecondary))),
                    Text('8.75', style: ts(11, weight: FontWeight.w700, color: p.accentBright, tabular: true)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 9, 7, 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, weight: FontWeight.w700)),
                    if (caption != null) Text(caption!, style: ts(11, color: AppColors.textSecondary)),
                  ]),
                ),
                if (selected) Text('✓', style: ts(15, weight: FontWeight.w800, color: AppColors.accentBright)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
