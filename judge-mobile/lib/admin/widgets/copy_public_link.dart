// "Copy Public Link" (Overview and Rounds headers): copies the public results
// link `https://judge.kreen.asia/#/<slug>/round_<n>` (see public_results.dart).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../public/public_results.dart';
import '../../theme/tokens.dart';
import '../admin_models.dart';
import '../admin_scope.dart';
import '../admin_store.dart';
import 'admin_ui.dart';

class CopyPublicLinkButton extends StatelessWidget {
  const CopyPublicLinkButton({super.key});

  /// Shown once the event's slug is known and a round has been opened (a
  /// draft round has no public page).
  static bool available(AdminStore admin) =>
      admin.event?.slug != null && admin.rounds.any((r) => r.status != 'draft');

  @override
  Widget build(BuildContext context) => AdminBtn(
        'Copy Public Link',
        onTap: () {
          final admin = AdminScope.read(context);
          final slug = admin.event?.slug;
          if (slug != null) _copyPublicLink(context, slug, admin.orderedRounds);
        },
      );
}

/// "Copy Public Link": with at most one finalized round, copies the latest
/// opened round's link at once; with more, a menu under the button picks the
/// round (every opened round, in order).
Future<void> _copyPublicLink(BuildContext button, String slug, List<AdminRound> rounds) async {
  final opened = rounds.where((r) => r.status != 'draft').toList();
  AdminRound? round = opened.last;
  if (rounds.where((r) => r.status == 'finalized').length > 1) {
    final box = button.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(button).context.findRenderObject()! as RenderBox;
    final anchor = Rect.fromPoints(
      box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    ).shift(const Offset(0, 6));
    round = await showMenu<AdminRound>(
      context: button,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.borderStrong),
      ),
      items: [
        for (final r in opened)
          PopupMenuItem(
            value: r,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.order.toString().padLeft(2, '0')} · ${r.name}', style: ts(14, weight: FontWeight.w700)),
              Text('${r.status[0].toUpperCase()}${r.status.substring(1)}',
                  style: ts(12, color: AppColors.textSecondary)),
            ]),
          ),
      ],
    );
    if (round == null) return; // menu dismissed
  }
  final url = publicResultsUrl(slug, round.order);
  await Clipboard.setData(ClipboardData(text: url));
  if (!button.mounted) return;
  ScaffoldMessenger.of(button)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: AppColors.surfaceRaised,
      content: Text('Public link for ${round.name} copied: $url', style: ts(14)),
    ));
}
