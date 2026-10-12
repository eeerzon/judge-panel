// Shared chrome every round screen renders — port of assets/js/chrome.js:
// offline banner and the "Prototype Controls" dev panel. (The idle timeout
// to Standby was removed: Standby is hidden for now.)

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';

/// Dev panel is a prototype affordance (like `?preview=1` in the HTML), off
/// by default. Enable with `--dart-define=KREEN_DEV_PANEL=true`.
const kShowDevPanel = bool.fromEnvironment('KREEN_DEV_PANEL');

class JudgeChrome extends StatelessWidget {
  const JudgeChrome({super.key, required this.roundId, required this.child});

  final String roundId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final store = JudgeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.connectionState == ConnectionStateKind.offline) const OfflineBanner(),
        if (kShowDevPanel) DevPanel(roundId: roundId),
        Expanded(child: child),
      ],
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.statusDraftBg,
          border: Border(bottom: BorderSide(color: AppColors.statusDraftBorder)),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text('No connection', style: ts(14, weight: FontWeight.w700, color: AppColors.statusDraftColor)),
            Text(
              'Your scores are safe on this device and will sync when connection returns.',
              style: ts(14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deliberately looks like a debug tool (monospace, dashed border, near-black)
/// — do not restyle it to look like product UI (design-system §6.7).
class DevPanel extends StatefulWidget {
  const DevPanel({super.key, required this.roundId});
  final String roundId;

  @override
  State<DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends State<DevPanel> {
  bool _open = false;

  static TextStyle get _mono =>
      TextStyle(fontFamily: kMonoFontFamily, fontSize: 11, color: AppColors.textSecondary);

  Widget _btn(String label, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? AppColors.statusErrorColor : AppColors.border),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(label,
              style: _mono.copyWith(color: active ? AppColors.statusErrorColor : AppColors.textPrimary)),
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text.toUpperCase(), style: _mono.copyWith(letterSpacing: 0.66)),
      );

  @override
  Widget build(BuildContext context) {
    final store = JudgeScope.of(context);
    const dashed = Border(bottom: BorderSide(color: AppColors.devPanelBorder));
    return Container(
      decoration: const BoxDecoration(color: AppColors.devPanelBg, border: dashed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Text('⚙ Prototype Controls', style: _mono),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heading('Sync · ${store.syncState.name}${store.syncMessage != null ? ' — ${store.syncMessage}' : ''}'),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _btn('Retry sync now', store.flushAll),
                    _btn('Reload round', () => store.ensureRound(widget.roundId, force: true)),
                    _btn('Clear local drafts', store.clearLocalDrafts, active: true),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
