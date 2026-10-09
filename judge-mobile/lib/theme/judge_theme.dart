// Judge Mode theme per event. The server is the authority: an admin picks
// it in Settings (`PATCH /judge/admin/events/{idVote}/settings` `id_theme`)
// and judges receive it in `/judge/rounds` → `vote.theme`. This device keeps
// a copy per event (SharedPreferences `kreenJudgeTheme.<idVote>`) so Judge
// Mode keeps its colours offline. Theme id 0 ("default") IS the KREEN
// default; no choice (`id_theme` null, `source: "vote"`) is KREEN too.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// One entry of `GET /create-vote/themes`.
class EventTheme {
  const EventTheme({required this.id, required this.name, required this.primary, required this.icon});

  final int id;
  final String name;

  /// `primary` / `icon` ("r,g,b"). Only their hue is used: Judge Mode stays a
  /// dark UI, the palette is the KREEN one re-tinted (AppPalette.fromHue).
  final Color primary, icon;

  /// Theme id 0 ("default" in the API) is the KREEN default.
  static const kreenId = 0;
  bool get isKreen => id == kreenId;

  double get hue => HSLColor.fromColor(primary).hue;
  AppPalette get palette => isKreen ? AppPalette.kreen : AppPalette.fromHue(hue);

  static Color? _rgb(Object? v) {
    final parts = '${v ?? ''}'.split(',').map((p) => int.tryParse(p.trim())).toList();
    if (parts.length != 3 || parts.any((p) => p == null || p < 0 || p > 255)) return null;
    return Color.fromARGB(255, parts[0]!, parts[1]!, parts[2]!);
  }

  /// The admin-chosen Judge Mode theme in a `theme` object (event detail,
  /// settings, `/judge/rounds` → `vote.theme`). Null = KREEN: `source:
  /// "vote"` (none chosen — it is the vote's web theme) or the default id 0.
  static EventTheme? chosenFrom(Object? theme) {
    if (theme is! Map || '${theme['source'] ?? ''}' == 'vote') return null;
    final chosen = fromApi(Map<String, dynamic>.from(theme));
    return chosen == null || chosen.isKreen ? null : chosen;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primary': '${(primary.r * 255).round()},${(primary.g * 255).round()},${(primary.b * 255).round()}',
        'icon': '${(icon.r * 255).round()},${(icon.g * 255).round()},${(icon.b * 255).round()}',
      };

  static EventTheme? fromApi(Map<String, dynamic> j) {
    final id = j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}');
    final primary = _rgb(j['primary']);
    if (id == null || primary == null) return null;
    final name = '${j['name'] ?? ''}'.trim();
    return EventTheme(
      id: id,
      name: id == kreenId
          ? 'KREEN'
          : name.isEmpty
              ? 'Theme $id'
              : name[0].toUpperCase() + name.substring(1),
      primary: primary,
      icon: _rgb(j['icon']) ?? primary,
    );
  }

  /// `GET /create-vote/themes` as captured on 2026-10-02 — used until (or
  /// when) the live list cannot be loaded.
  static const builtIn = [
    EventTheme(id: 0, name: 'KREEN', primary: Color(0xFFEB2E2E), icon: Color(0xFFEB2E2E)),
    EventTheme(id: 1, name: 'Blue', primary: Color(0xFF29458F), icon: Color(0xFF96B3FF)),
    EventTheme(id: 2, name: 'Pink', primary: Color(0xFF921A40), icon: Color(0xFFFFA7C0)),
    EventTheme(id: 3, name: 'Green', primary: Color(0xFF008F5F), icon: Color(0xFF86E5C6)),
    EventTheme(id: 4, name: 'Purple', primary: Color(0xFF7149C6), icon: Color(0xFFD5B8FF)),
    EventTheme(id: 5, name: 'Turqoise', primary: Color(0xFF006769), icon: Color(0xFF95EBED)),
    EventTheme(id: 6, name: 'Gold', primary: Color(0xFFCE8B0B), icon: Color(0xFFFEBF37)),
  ];
}

class JudgeThemeStore extends ChangeNotifier {
  JudgeThemeStore([this._prefs]);

  static const storageKey = 'kreenJudgeTheme';

  static Future<JudgeThemeStore> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    return JudgeThemeStore(prefs);
  }

  final SharedPreferences? _prefs;

  /// Event id → chosen theme (null = none), as last received from the server.
  final Map<String, EventTheme?> _byEvent = {};

  /// Themes an admin can choose (`GET /create-vote/themes`).
  List<EventTheme> themes = EventTheme.builtIn;

  /// Live list, KREEN (id 0) always first.
  void setThemes(List<EventTheme> live) {
    if (live.isEmpty) return;
    themes = [
      live.where((t) => t.isKreen).firstOrNull ?? EventTheme.builtIn.first,
      ...live.where((t) => !t.isKreen),
    ];
    notifyListeners();
  }

  /// The event's chosen theme; null = KREEN.
  EventTheme? themeFor(String? eventId) {
    if (eventId == null) return null;
    if (_byEvent.containsKey(eventId)) return _byEvent[eventId];
    EventTheme? cached;
    try {
      final raw = _prefs?.getString('$storageKey.$eventId');
      if (raw != null) cached = EventTheme.fromApi(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}
    return _byEvent[eventId] = cached;
  }

  int? themeIdFor(String? eventId) => themeFor(eventId)?.id;

  /// Palette for Judge Mode screens showing [eventIds]: the events' theme
  /// when they all share one, otherwise KREEN.
  AppPalette paletteFor(Iterable<String?> eventIds) {
    final ids = eventIds.whereType<String>().toSet();
    if (ids.isEmpty) return AppPalette.kreen;
    final chosen = {for (final e in ids) themeFor(e)?.id};
    if (chosen.length != 1 || chosen.single == null) return AppPalette.kreen;
    return themeFor(ids.first)?.palette ?? AppPalette.kreen;
  }

  /// Takes each event's theme from the rounds list (`vote.theme`). Rounds
  /// without a `theme` object (older server) leave the cached value alone.
  void syncFromRounds(Iterable<({String? eventId, Map<String, dynamic>? theme})> rounds) {
    for (final r in rounds) {
      final id = r.eventId;
      if (id != null && r.theme != null) remember(id, EventTheme.chosenFrom(r.theme));
    }
  }

  /// Records what the server says for [eventId] (null = no choice).
  void remember(String eventId, EventTheme? theme) {
    final before = themeFor(eventId);
    if (before?.id == theme?.id && before?.primary == theme?.primary) return;
    _byEvent[eventId] = theme;
    try {
      if (theme == null) {
        _prefs?.remove('$storageKey.$eventId');
      } else {
        _prefs?.setString('$storageKey.$eventId', jsonEncode(theme.toJson()));
      }
    } catch (_) {}
    notifyListeners();
  }
}
