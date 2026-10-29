import 'package:flutter/material.dart';

/// Fade within the space above navigation, then remove paint, focus and hits.
/// A full 2x-height slide can leave a raised FAB visible underneath a floating bar.
///
/// When [maintainSize] is true the hidden child keeps its size. That matters
/// for the Scaffold bottom navigation bar: collapsing it to zero height
/// changes the Scaffold geometry, rebuilds the body with a different
/// MediaQuery padding, moves the scroll position and drops the drag surface
/// (its LayoutBuilder returns a shrink widget at zero width). Floating
/// action buttons keep the default collapsing behaviour.
class ScrollHidingAction extends StatelessWidget {
  const ScrollHidingAction(
      {super.key,
      required this.animation,
      required this.child,
      this.maintainSize = false});

  final Animation<double> animation;
  final Widget child;
  final bool maintainSize;

  @override
  Widget build(BuildContext context) {
    final curved = animation.drive(CurveTween(curve: Curves.easeInOut));
    return AnimatedBuilder(
      animation: animation,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      ),
      builder: (_, child) => Visibility(
        visible: animation.value > 0,
        maintainState: true,
        maintainSize: maintainSize,
        maintainAnimation: maintainSize,
        child: child!,
      ),
    );
  }
}
