import 'package:flutter/widgets.dart';

import '../admin/admin_scope.dart';
import '../admin/admin_store.dart';
import '../theme/judge_theme.dart';
import 'judge_store.dart';
import 'session_store.dart';

/// Makes the stores available to the widget tree. Widgets that call
/// [JudgeScope.of] rebuild whenever the JudgeStore notifies.
class AppScope extends StatefulWidget {
  const AppScope({super.key, required this.judge, required this.session, required this.admin, this.themes, required this.child});

  final JudgeStore judge;
  final AdminStore admin;
  final SessionStore session;

  /// Judge Mode theme per event (in memory when omitted, e.g. in tests).
  final JudgeThemeStore? themes;
  final Widget child;

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  late final JudgeThemeStore _themes = widget.themes ?? JudgeThemeStore();

  @override
  void initState() {
    super.initState();
    widget.judge.addListener(_syncThemes);
    _syncThemes();
  }

  @override
  void dispose() {
    widget.judge.removeListener(_syncThemes);
    super.dispose();
  }

  /// `/judge/rounds` carries each event's Judge Mode theme (`vote.theme`).
  void _syncThemes() =>
      _themes.syncFromRounds([for (final r in widget.judge.rounds ?? const []) (eventId: r.eventId, theme: r.eventTheme)]);

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      notifier: widget.session,
      child: JudgeScope(
        notifier: widget.judge,
        child: AdminScope(
          notifier: widget.admin,
          child: JudgeThemeScope(notifier: _themes, child: widget.child),
        ),
      ),
    );
  }
}

class JudgeThemeScope extends InheritedNotifier<JudgeThemeStore> {
  const JudgeThemeScope({super.key, required super.notifier, required super.child});

  static JudgeThemeStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<JudgeThemeScope>()!.notifier!;

  static JudgeThemeStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<JudgeThemeScope>()!.notifier!;
}

class JudgeScope extends InheritedNotifier<JudgeStore> {
  const JudgeScope({super.key, required super.notifier, required super.child});

  /// Subscribes the caller to store changes.
  static JudgeStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<JudgeScope>()!.notifier!;

  /// Reads the store without subscribing (for callbacks).
  static JudgeStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<JudgeScope>()!.notifier!;
}

class SessionScope extends InheritedNotifier<SessionStore> {
  const SessionScope({super.key, required super.notifier, required super.child});

  static SessionStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  static SessionStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
