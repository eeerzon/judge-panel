// Event picker — `GET /judge/admin/dashboard`. The HTML prototype manages a
// single event; the API is multi-event, so Admin starts here and every other
// Admin page works on the chosen event. Same visual language as the Admin
// pages (context bar, page header, cards, admin buttons).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../navigation/judge_nav.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart' show MaxWidth, Pressable;
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_scope.dart';
import '../widgets/admin_ui.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  late final _search = TextEditingController(text: AdminScope.read(context).eventsSearch);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final admin = AdminScope.read(context);
    if (admin.events.isEmpty && !admin.eventsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => admin.loadEvents(search: admin.eventsSearch));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => AdminScope.read(context).loadEvents(search: value));
  }

  Future<void> _open(AdminEvent event) async {
    final admin = AdminScope.read(context);
    if (admin.openingEventId != null) return;
    final error = await admin.openEvent(event.id);
    if (!mounted) return;
    if (error == null) {
      AdminNav.go(context, AdminRoutes.overview);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceRaised,
        content: Text(error, style: ts(14)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final compact = AdminLayout.compact(context);
    final width = MediaQuery.sizeOf(context).width;
    final padX = compact ? 18.0 : (width * 0.032).clamp(24.0, 48.0);

    final Widget body;
    if (admin.events.isEmpty && admin.eventsLoading) {
      body = Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2.5)),
      );
    } else if (admin.events.isEmpty && admin.eventsError != null) {
      body = AdminStateCard(
        title: 'Unable to load events',
        description: admin.eventsError,
        error: true,
        icon: '!',
        action: AdminBtn('Try Again', onTap: () => admin.loadEvents()),
      );
    } else if (admin.events.isEmpty) {
      body = AdminStateCard(
        title: 'No events found',
        description: admin.eventsSearch.isEmpty ? 'There are no events for this account yet.' : 'Try another search.',
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminGrid(
          columns: AdminLayout.gridColumns(context, wide: 3),
          children: [
            for (final e in admin.events)
              _EventCard(event: e, opening: admin.openingEventId == e.id, onOpen: () => _open(e)),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Text('Showing ${admin.events.length} of ${admin.eventsTotal} events',
              style: ts(13, color: AppColors.textSecondary)),
        ),
        if (admin.hasMoreEvents) ...[
          const SizedBox(height: 12),
          Center(
            child: AdminBtn(admin.eventsLoading ? 'Loading…' : 'Load More',
                onTap: admin.eventsLoading ? null : () => admin.loadEvents(more: true)),
          ),
        ],
      ]);
    }

    return JudgeBackHandler(
      onBack: () => JudgeNav.goToModeSelector(context),
      child: Scaffold(
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _TopBar(padX: padX, compact: compact),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: () => admin.loadEvents(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(padX, compact ? 20 : 34, padX, compact ? 24 : 60),
                  child: MaxWidth(
                    maxWidth: 1600 - padX * 2,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const AdminPageHeader(
                        eyebrow: 'Admin workspace',
                        title: 'Events',
                        description: 'Choose the event you want to manage.',
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextField(
                          controller: _search,
                          onChanged: _onSearch,
                          style: ts(14),
                          decoration: adminFieldDecoration(
                            hint: 'Search event name',
                            prefix: Padding(
                              padding: EdgeInsets.only(left: 14, right: 8),
                              child: AdminIcon('search', size: 16, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                      body,
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Context-bar look-alike: brand, account, mode switch and log out.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.padX, required this.compact});
  final double padX;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final admin = AdminScope.of(context);
    Widget link(String icon, String label, VoidCallback onTap) => Pressable(
          onTap: onTap,
          pressedScale: 0.98,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AdminIcon(icon, size: 16, color: AppColors.textSecondary),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(label, style: ts(13, weight: FontWeight.w600, color: AppColors.textSecondary)),
              ],
            ]),
          ),
        );
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 58 : 72),
      padding: EdgeInsets.symmetric(horizontal: padX, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: AdminColors.contextBar,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
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
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('KREEN JUDGING', maxLines: 1, style: ts(14, weight: FontWeight.w700, letterSpacingEm: 0.08)),
            Text('${admin.actorRole} · ${session.judge?.name ?? admin.actor}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(12, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 12),
        if (session.canJudge) ...[
          link('switch', 'Switch to Judge Mode', () => JudgeNav.goToMyRounds(context)),
          const SizedBox(width: 8),
        ],
        link('logout', 'Log Out', () => SessionScope.read(context).logout()),
      ]),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.opening, required this.onOpen});
  final AdminEvent event;
  final bool opening;
  final VoidCallback onOpen;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final counts = event.roundCounts;
    final roundsText = counts.total == 0
        ? 'No rounds yet'
        : [
            '${counts.total} ${counts.total == 1 ? 'round' : 'rounds'}',
            if (counts.open > 0) '${counts.open} open',
            if (counts.draft > 0) '${counts.draft} draft',
            if (counts.closed > 0) '${counts.closed} closed',
            if (counts.finalized > 0) '${counts.finalized} finalized',
          ].join(' · ');
    final voting = event.votingOpensAt != null && event.votingClosesAt != null
        ? 'Voting ${_day(event.votingOpensAt!)} – ${_day(event.votingClosesAt!)}'
        : null;
    final grandFinal = event.grandFinalOn != null ? 'Grand final ${_day(event.grandFinalOn!)}' : null;

    return Pressable(
      onTap: onOpen,
      pressedScale: 0.99,
      child: AdminPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 120, child: AdminPhoto(photo: event.banner ?? '', name: event.title)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(event.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(18, weight: FontWeight.w700, height: 1.3)),
                  ),
                  const SizedBox(width: 12),
                  AdminStatus(event.active ? 'active' : 'inactive'),
                ]),
                const SizedBox(height: 10),
                for (final line in [?voting, ?grandFinal])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(line, style: ts(13, color: AppColors.textSecondary, height: 1.4)),
                  ),
                const SizedBox(height: 12),
                Text(roundsText, style: ts(13, weight: FontWeight.w700, color: AppColors.accent)),
                const SizedBox(height: 18),
                const Spacer(),
                AdminBtn(opening ? 'Opening…' : 'Manage Event →',
                    variant: AdminBtnVariant.primary, expand: true, onTap: opening ? null : onOpen),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
