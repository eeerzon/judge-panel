// Admin shell — port of admin-shell.js + admin-navigation.js:
// landscape: left sidebar (236px, 208px ≤1100px) + event context bar;
// portrait / ≤760px: context bar + 5-slot bottom bar (Home, Rounds, Live,
// Results, More) with a More sheet. One navigation model feeds both.

import 'package:flutter/material.dart';

import '../../navigation/judge_nav.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart' show MaxWidth, Pressable;
import '../admin_nav.dart';
import '../admin_scope.dart';
import 'admin_ui.dart';

class _NavItem {
  const _NavItem(this.key, this.label, this.icon, this.route, [this.mobileLabel]);
  final String key, label, icon, route;
  final String? mobileLabel;
}

const _navigation = <(String?, List<_NavItem>)>[
  (null, [_NavItem('overview', 'Overview', 'home', AdminRoutes.overview, 'Home')]),
  ('Event', [
    _NavItem('rounds', 'Rounds', 'rounds', AdminRoutes.rounds, 'Rounds'),
    _NavItem('contestants', 'Contestants', 'person', AdminRoutes.contestants),
    _NavItem('judges', 'Judges', 'judges', AdminRoutes.judges),
  ]),
  ('Operations', [
    _NavItem('live', 'Live', 'live', AdminRoutes.live, 'Live'),
    _NavItem('results', 'Results', 'results', AdminRoutes.results, 'Results'),
  ]),
  ('System', [
    _NavItem('settings', 'Settings', 'settings', AdminRoutes.settings),
    _NavItem('audit', 'Audit Log', 'history', AdminRoutes.audit),
  ]),
];

_NavItem _item(String key) => _navigation.expand((s) => s.$2).firstWhere((i) => i.key == key);

/// Wraps every Admin page. [children] are laid out in the scrolling content
/// column (max 1600px, responsive padding) under the event context bar.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.activeNav, required this.children, this.onBack});

  /// Global destination key (round pages always pass `rounds`).
  final String activeNav;
  final List<Widget> children;

  /// System back; defaults to Overview (Overview itself → the event list with
  /// the Admin API, else Mode Selector).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final compact = AdminLayout.compact(context);
    final width = MediaQuery.sizeOf(context).width;
    final padX = compact ? 18.0 : (width * 0.032).clamp(24.0, 48.0);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ContextBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(padX, compact ? 20 : 34, padX, compact ? 24 : 60),
            child: MaxWidth(
              maxWidth: 1600 - padX * 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      ],
    );

    return JudgeBackHandler(
      onBack: onBack ??
          () {
            final admin = AdminScope.read(context);
            if (activeNav != 'overview') return AdminNav.go(context, AdminRoutes.overview);
            if (!admin.connected) return JudgeNav.goToModeSelector(context);
            admin.closeEvent();
            AdminNav.go(context, AdminRoutes.events);
          },
      child: Scaffold(
        body: SafeArea(
          bottom: !compact,
          child: compact
              ? content
              : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Sidebar(activeNav: activeNav, width: width <= 1100 ? 208 : (width >= 1680 ? 240 : 236)),
                  Expanded(child: content),
                ]),
        ),
        bottomNavigationBar: compact ? _BottomNav(activeNav: activeNav) : null,
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar();

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final compact = AdminLayout.compact(context);
    final width = MediaQuery.sizeOf(context).width;
    final padX = compact ? 18.0 : (width * 0.032).clamp(24.0, 48.0);
    final settings = admin.eventSettings;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 58 : 72),
      padding: EdgeInsets.symmetric(horizontal: padX, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: AdminColors.contextBar,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(settings.eventName,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(compact ? 14 : 15, weight: FontWeight.w700)),
            SizedBox(height: compact ? 0 : 2),
            Text(settings.eventYear.toUpperCase(),
                style: ts(compact ? 11 : 12,
                    weight: FontWeight.w600, color: AppColors.textSecondary, letterSpacingEm: compact ? 0.04 : 0.1)),
          ]),
        ),
        if (admin.connected) ...[
          const SizedBox(width: 12),
          AdminBtn('Switch Event', small: true, onTap: () {
            admin.closeEvent();
            AdminNav.go(context, AdminRoutes.events);
          }),
        ],
        if (!compact) ...[
          const SizedBox(width: 20),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.statusScoredFill,
              boxShadow: [BoxShadow(color: AppColors.statusScoredGlow, blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 9),
          Text(admin.actorRole, style: ts(13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.activeNav, required this.width});
  final String activeNav;
  final double width;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final session = SessionScope.of(context);
    final narrow = width < 236;
    return Container(
      width: width,
      padding: EdgeInsets.fromLTRB(narrow ? 10 : 13, 20, narrow ? 10 : 13, 14),
      decoration: BoxDecoration(
        color: AdminColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: CustomScrollView(slivers: [
        SliverList.list(children: [
          // .admin-brand
          Pressable(
            onTap: () => AdminNav.go(context, AdminRoutes.overview),
            pressedScale: 0.99,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.accentDeep),
                  ),
                  child: Text('K', style: ts(14, weight: FontWeight.w800, color: AppColors.accentBright)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text('KREEN JUDGING',
                      maxLines: 1, overflow: TextOverflow.fade, softWrap: false,
                      style: ts(14, weight: FontWeight.w700, letterSpacingEm: 0.08)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          for (final (section, items) in _navigation)
            Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (section != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
                    child: Text(section.toUpperCase(),
                        style: ts(11, weight: FontWeight.w700, color: AppColors.textSecondary, letterSpacingEm: 0.14)),
                  ),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 3),
                  _SidebarItem(item: items[i], active: items[i].key == activeNav),
                ],
              ]),
            ),
        ]),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(admin.actorRole, style: ts(12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(session.judge?.name ?? admin.actor, style: ts(14, weight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (session.canJudge) ...[
                  _ModeSwitchButton(label: '← Switch to Judge Mode', onTap: () => JudgeNav.goToMyRounds(context)),
                  const SizedBox(height: 7),
                ],
                _ModeSwitchButton(label: 'Log Out', onTap: () => SessionScope.read(context).logout()),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.active});
  final _NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      child: Pressable(
        onTap: () => AdminNav.go(context, item.route),
        pressedScale: 0.99,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? const Color.fromRGBO(200, 155, 75, 0.34) : Colors.transparent),
          ),
          foregroundDecoration: active
              ? BoxDecoration(border: Border(left: BorderSide(color: AppColors.accent, width: 2)))
              : null,
          child: Row(children: [
            AdminIcon(item.icon, color: active ? AppColors.accentBright : AdminColors.navIcon),
            const SizedBox(width: 11),
            Flexible(
              child: Text(item.label,
                  style: ts(14, weight: FontWeight.w600, color: active ? AppColors.textPrimary : AppColors.textSecondary)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ModeSwitchButton extends StatelessWidget {
  const _ModeSwitchButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        pressedScale: 0.99,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Text(label, style: ts(13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.activeNav});
  final String activeNav;

  @override
  Widget build(BuildContext context) {
    final activeKey = ['contestants', 'judges', 'settings', 'audit'].contains(activeNav) ? 'more' : activeNav;
    Widget slot(String key) {
      final isMore = key == 'more';
      final item = isMore ? null : _item(key);
      final active = key == activeKey;
      return Expanded(
        child: Semantics(
          selected: active,
          child: Pressable(
            onTap: () => isMore ? _showMoreSheet(context) : AdminNav.go(context, item!.route),
            pressedScale: 0.97,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
              decoration: BoxDecoration(
                color: active ? AppColors.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                AdminIcon(isMore ? 'more' : item!.icon,
                    size: 23, color: active ? AppColors.accentBright : AppColors.textSecondary),
                const SizedBox(height: 4),
                Text(isMore ? 'More' : item!.mobileLabel ?? item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(11, weight: FontWeight.w600, color: active ? AppColors.textPrimary : AppColors.textSecondary)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Color.fromRGBO(27, 18, 21, 0.98),
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
        boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.24), blurRadius: 24, offset: Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [for (final k in ['overview', 'rounds', 'live', 'results', 'more']) slot(k)]),
        ),
      ),
    );
  }
}

void _showMoreSheet(BuildContext context) {
  final admin = AdminScope.read(context);
  final session = SessionScope.read(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: const Color.fromRGBO(8, 4, 4, 0.62),
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82 > 640 ? 640 : MediaQuery.sizeOf(context).height * 0.82),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: AppColors.borderStrong),
    ),
    builder: (sheet) {
      Widget link(String icon, String label, VoidCallback onTap) => Pressable(
            onTap: () {
              Navigator.of(sheet).pop();
              onTap();
            },
            pressedScale: 0.99,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                AdminIcon(icon),
                const SizedBox(width: 13),
                Text(label, style: ts(14)),
              ]),
            ),
          );
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(admin.actorRole, style: ts(12, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(session.judge?.name ?? admin.actor, style: ts(18, weight: FontWeight.w700)),
                  ]),
                ),
                AdminIconBtn(label: '×', semanticLabel: 'Close menu', onTap: () => Navigator.of(sheet).pop()),
              ]),
            ),
            const SizedBox(height: 10),
            link('person', 'Contestants', () => AdminNav.go(context, AdminRoutes.contestants)),
            link('judges', 'Judges', () => AdminNav.go(context, AdminRoutes.judges)),
            link('settings', 'Settings', () => AdminNav.go(context, AdminRoutes.settings)),
            link('history', 'Audit Log', () => AdminNav.go(context, AdminRoutes.audit)),
            if (session.canJudge) link('switch', 'Switch to Judge Mode', () => JudgeNav.goToMyRounds(context)),
            link('logout', 'Log Out', () => SessionScope.read(context).logout()),
          ]),
        ),
      );
    },
  );
}
