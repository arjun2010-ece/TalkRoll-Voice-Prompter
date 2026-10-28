import 'package:flutter/material.dart';

/// A full-screen route that fades the screen it replaces behind a black cover (the prompt background) and brings its
/// own content in just as the cover lands, so the old text is gone before the new text shows and there is no empty beat
/// in between.
class FadeCoverRoute<T> extends PageRouteBuilder<T> {
  FadeCoverRoute({required WidgetBuilder builder})
    : super(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (_, animation, _, child) => Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.4, curve: Curves.easeOut)),
              child: const ColoredBox(color: Colors.black),
            ),
            FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: const Interval(0.3, 1, curve: Curves.easeOut)),
              child: child,
            ),
          ],
        ),
      );
}
