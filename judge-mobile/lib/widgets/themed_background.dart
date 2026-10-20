// App background on every page (except Splash and Login): the theme picture
// (bg-vote-<id>.jpg, loaded here with Image.network) under a dark tint of the
// page's palette, so the dark UI and its light text stay readable on the
// light pictures. While loading, or without network, the plain dark
// background shows. Which picture a page gets: JudgeNav.onGenerateRoute.

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class ThemedBackground extends StatelessWidget {
  const ThemedBackground({super.key, required this.url, required this.child});

  final String url;
  final Widget child;

  /// How much of the dark base covers the picture: 0.0 = picture only,
  /// 1.0 = plain dark (no picture visible). Change it here to tune.
  static const tint = 0.80;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: AppColors.bgBase),
          Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Web: the picture host sends no CORS header.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          ColoredBox(color: AppColors.bgBase.withValues(alpha: tint)),
          child,
        ],
      );
}
