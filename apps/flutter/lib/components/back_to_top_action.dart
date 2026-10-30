import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/extensions.dart';

/// A floating back-to-top button, modelled on TiebaLite's
/// `DefaultBackToTopFAB` (`ui/widgets/compose/Buttons.kt`).
///
/// Colour follows the app theme instead of a fixed brown: it uses
/// `colorScheme.primaryContainer` / `onPrimaryContainer`, which in this
/// app comes from `DynamicColorBuilder` in `main.dart` (system dynamic
/// colour when Material You is enabled, otherwise the configured seed
/// colour), exactly like a Material 3 FAB in TiebaLite.
///
/// It only appears once the list has been scrolled past [threshold], so it
/// never covers the first screen of content. Tapping it scrolls the list
/// back to the top with the existing [ScrollControllerExt.animToTop]
/// animation and does not refresh, unlike a tab re-tap. Long-pressing it
/// does the TiebaLite thing: a light haptic, scroll to top, and then
/// [onLongPress] (the feed refresh in the caller).
class BackToTopAction extends StatefulWidget {
  const BackToTopAction({
    super.key,
    required this.controller,
    this.threshold = 600,
    this.onLongPress,
  });

  final ScrollController? controller;
  final double threshold;

  /// Called after scrolling to top on long-press, e.g. to refresh the
  /// current feed. The scroll itself is always done by this widget.
  final VoidCallback? onLongPress;

  @override
  State<BackToTopAction> createState() => _BackToTopActionState();
}

class _BackToTopActionState extends State<BackToTopAction> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onScroll);
    _onScroll();
  }

  @override
  void didUpdateWidget(BackToTopAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onScroll);
      widget.controller?.addListener(_onScroll);
      _onScroll();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.controller;
    // Only rebuild when visibility actually flips, not on every scroll tick.
    final visible = controller != null &&
        controller.hasClients &&
        controller.offset > widget.threshold;
    if (visible != _visible && mounted) {
      setState(() => _visible = visible);
    }
  }

  void _onLongPress() {
    if (widget.onLongPress == null) return;
    HapticFeedback.mediumImpact();
    widget.controller?.animToTop();
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: _visible ? 1 : 0.8,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_visible,
          child: Material(
            color: colors.primaryContainer,
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.controller?.animToTop,
              onLongPress:
                  widget.onLongPress == null ? null : _onLongPress,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.arrow_upward,
                  color: colors.onPrimaryContainer,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
