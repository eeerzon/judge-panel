// The only renderer for round context + secondary navigation — port of
// admin-round-workspace.js. Tabs: Overview · Monitoring · Contestants ·
// Judges · Criteria · Results · Settings (Soon). Global "Rounds" stays active.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/common.dart' show BackLink;
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import '../screens/overview_screen.dart' show showRoundForm;
import 'admin_shell.dart';
import 'admin_ui.dart';

enum RoundTab { overview, monitoring, contestants, judges, criteria, results, settings }

const _tabs = [
  (RoundTab.overview, 'Overview', AdminRoutes.roundOverview),
  (RoundTab.monitoring, 'Monitoring', AdminRoutes.monitoring),
  (RoundTab.contestants, 'Contestants', AdminRoutes.roundContestants),
  (RoundTab.judges, 'Judges', AdminRoutes.roundJudges),
  (RoundTab.criteria, 'Criteria', AdminRoutes.criteria),
  (RoundTab.results, 'Results', AdminRoutes.roundResults),
  (RoundTab.settings, 'Settings · Soon', null),
];

/// With the Admin API every round page reloads the round when it opens
/// ([AdminStore.loadRound], plus [onLoad] for page-specific data) and shows
/// a loading / error state until the round has been loaded once.
class RoundWorkspace extends StatefulWidget {
  const RoundWorkspace({
    super.key,
    required this.roundId,
    required this.activeTab,
    required this.pageTitle,
    this.pageDescription,
    required this.children,
    this.onBack,
    this.onLoad,
  });

  final int roundId;
  final RoundTab activeTab;
  final String pageTitle;
  final String? pageDescription;
  final List<Widget> children;

  /// Detail pages go back to their parent tab; tabs go back to Rounds.
  final VoidCallback? onBack;

  /// Extra API load after the round (e.g. a result's per-judge scores).
  final Future<void> Function(AdminStore admin)? onLoad;

  @override
  State<RoundWorkspace> createState() => _RoundWorkspaceState();
}

class _RoundWorkspaceState extends State<RoundWorkspace> {
  @override
  void initState() {
    super.initState();
    final admin = AdminScope.read(context);
    if (!admin.connected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await admin.loadRound(widget.roundId);
      await widget.onLoad?.call(admin);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roundId = widget.roundId;
    final onBack = widget.onBack;
    final admin = AdminScope.of(context);
    final round = admin.getRound(roundId)!;
    final readiness = admin.getRoundReadiness(roundId);
    final compact = AdminLayout.compact(context);

    final facts = Wrap(
      spacing: compact ? 5 : 12,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: '${readiness.contestantsAssigned}', style: ts(compact ? 12 : 13, weight: FontWeight.w700, tabular: true)),
          const TextSpan(text: ' contestants'),
        ]), style: ts(compact ? 12 : 13, color: AppColors.textSecondary)),
        if (compact) Text('·', style: ts(12, color: AppColors.textSecondary)),
        Text.rich(TextSpan(children: [
          TextSpan(text: '${readiness.judgesAssigned}', style: ts(compact ? 12 : 13, weight: FontWeight.w700, tabular: true)),
          const TextSpan(text: ' judges'),
        ]), style: ts(compact ? 12 : 13, color: AppColors.textSecondary)),
      ],
    );

    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: BackLink('Rounds', onTap: () => AdminNav.go(context, AdminRoutes.rounds), minHeight: compact ? 44 : 48),
      ),
      SizedBox(height: compact ? 0 : 2),
      if (!compact) ...[const AdminEyebrow('Round workspace'), const SizedBox(height: 7)],
      Row(children: [
        Flexible(child: Text(round.name, style: ts(compact ? 21 : 23, weight: FontWeight.w700))),
        const SizedBox(width: 10),
        AdminStatus(round.status),
        if (admin.connected) ...[
          const SizedBox(width: 10),
          AdminLink('Edit', color: AppColors.textSecondary, onTap: () => showRoundForm(context, round: round)),
        ],
      ]),
    ]);

    return AdminShell(
      activeNav: 'rounds',
      onBack: onBack ?? () => AdminNav.go(context, AdminRoutes.rounds),
      children: [
        // .admin-round-context
        Container(
          margin: EdgeInsets.only(bottom: compact ? 18 : 26),
          padding: EdgeInsets.fromLTRB(compact ? 14 : 24, compact ? 10 : 22, compact ? 14 : 24, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 10 : 20),
              child: compact
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 3), facts])
                  : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: heading),
                      const SizedBox(width: 18),
                      facts,
                    ]),
            ),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: _TabBar(roundId: roundId, active: widget.activeTab, compact: compact),
            ),
          ]),
        ),
        // page header (one title below the tabs)
        AdminPageHeader(title: widget.pageTitle, description: widget.pageDescription),
        if (!admin.isRoundLoaded(roundId) && admin.roundErrors[roundId] != null)
          AdminStateCard(
            title: 'Unable to load this round',
            description: admin.roundErrors[roundId],
            error: true,
            icon: '!',
            action: AdminBtn('Try Again', onTap: () => admin.loadRound(roundId)),
          )
        else if (!admin.isRoundLoaded(roundId))
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2.5)),
          )
        else
          ...widget.children,
      ],
    );
  }
}

class _TabBar extends StatefulWidget {
  const _TabBar({required this.roundId, required this.active, required this.compact});
  final int roundId;
  final RoundTab active;
  final bool compact;

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  final _activeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Reveal the active tab (the prototype scrolls it into view on load).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gap = widget.compact ? 18.0 : (width * 0.022).clamp(20.0, 32.0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < _tabs.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _tab(_tabs[i].$1, _tabs[i].$2, _tabs[i].$3),
        ],
      ]),
    );
  }

  Widget _tab(RoundTab tab, String label, String? route) {
    final active = tab == widget.active;
    final disabled = route == null;
    final text = Text(label,
        style: ts(widget.compact ? 12 : 13,
            weight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
            height: 1));
    final body = Container(
      key: active ? _activeKey : null,
      constraints: BoxConstraints(minHeight: widget.compact ? 48 : 56),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: active ? AppColors.accent : Colors.transparent, width: 2)),
      ),
      child: Center(widthFactor: 1, child: text),
    );
    if (disabled) return Opacity(opacity: 0.56, child: body);
    return Semantics(
      selected: active,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? null : () => AdminNav.round(context, route, widget.roundId),
        child: body,
      ),
    );
  }
}
