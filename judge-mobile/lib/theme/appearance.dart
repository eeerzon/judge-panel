// Night / light mode of the whole app, chosen with AppearanceToggle (Mode
// Selector, Admin top bar, Judge headers) and kept on this device
// (SharedPreferences `kreenAppearance`). Light mode is the default on a
// device that never chose; night mode is the original KREEN design. Light
// uses AppPalette.kreenLight / fromHue(light).
//
// The colours are read when a page builds, so a change re-opens the current
// page (KreenJudgeApp) instead of patching widgets in place.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceStore extends ChangeNotifier {
  /// In-memory store (tests, or no storage): night unless [_light].
  /// The app uses [load], where light is the default.
  AppearanceStore([this._prefs, this._light = false]);

  static const storageKey = 'kreenAppearance';

  static Future<AppearanceStore> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    var light = true; // default: light mode
    try {
      light = prefs?.getString(storageKey) != 'night';
    } catch (_) {}
    return AppearanceStore(prefs, light);
  }

  final SharedPreferences? _prefs;
  bool _light;

  /// Light mode on (false = night mode).
  bool get light => _light;

  void setLight(bool value) {
    if (value == _light) return;
    _light = value;
    try {
      _prefs?.setString(storageKey, value ? 'light' : 'night');
    } catch (_) {}
    notifyListeners();
  }

  void toggle() => setLight(!_light);
}
