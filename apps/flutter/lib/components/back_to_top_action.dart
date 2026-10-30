import 'package:flutter/material.dart';

import '../utils/extensions.dart';

/// A floating back-to-top button, modelled on the official client's
/// square button on the right edge above the bottom navigation bar.
///
/// It only appears once the list has been scrolled past [threshold], so it
/// never covers the first screen of content. Tapping it scrolls the list
/// back to the top with the existing [ScrollControllerExt.animToTop]
/// animation; unlike a tab re-tap it does not trigger a refresh.
class BackToTopAction extends StatefulWidget {
  const BackToTopAction({
    super.key,
    required this.controller,
    this.threshold = 600,
  });

  final ScrollController? controller;
  final double threshold;

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

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: _visible ? 1 : 0.8,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_visible,
          child: Material(
            color: const Color(0xFFBE9A5E),
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.controller?.animToTop,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.arrow_upward,
                  color: Color(0xFF2B2118),
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
