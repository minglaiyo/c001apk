import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/extensions.dart';
import '../utils/storage_util.dart';

/// A floating back-to-top button, modelled on TiebaLite's
/// `DefaultBackToTopFAB` (`ui/widgets/compose/Buttons.kt`).
///
/// Colour follows the app theme instead of a fixed brown: it uses
/// `colorScheme.primaryContainer` / `onPrimaryContainer`, which in this
/// app comes from `DynamicColorBuilder` in `main.dart` (system dynamic
/// colour when Material You is enabled, otherwise the configured seed
/// colour), exactly like a Material 3 FAB in TiebaLite.
///
/// The icon is TiebaLite's `VerticalAlignTop`: a horizontal line above an
/// up arrow, not a bare arrow.
///
/// It only appears once the list has been scrolled past [threshold], so it
/// never covers the first screen of content. Tapping it scrolls the list
/// back to the top with the existing [ScrollControllerExt.animToTop]
/// animation and does not refresh, unlike a tab re-tap. Long-pressing it
/// does the TiebaLite thing: a light haptic, scroll to top, and then
/// [onLongPress] (the feed refresh in the caller). Dragging it moves it:
/// [onDragUpdate]/[onDragEnd] report the drag to the parent, which owns
/// the button's position (see [DraggableBackToTop]).
class BackToTopAction extends StatefulWidget {
  const BackToTopAction({
    super.key,
    required this.controller,
    this.threshold = 600,
    this.onLongPress,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final ScrollController? controller;
  final double threshold;

  /// Called after scrolling to top on long-press, e.g. to refresh the
  /// current feed. The scroll itself is always done by this widget.
  final VoidCallback? onLongPress;

  /// Drag reporting for the parent-owned position. The pan recognizer
  /// only wins over tap/long-press once the pointer actually moves, so
  /// tapping and long-pressing keep working unchanged.
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final ValueChanged<DragEndDetails>? onDragEnd;

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
          child: GestureDetector(
            onPanUpdate: widget.onDragUpdate,
            onPanEnd: widget.onDragEnd,
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
                    Icons.vertical_align_top,
                    color: colors.onPrimaryContainer,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Positioned back-to-top button that can be dragged anywhere on the
/// page, like a floating ball. The dragged position is saved (normalized
/// to the screen size) in settings and shared by every back-to-top button;
/// without a saved position it sits at the left/right setting's default
/// spot, [bottom] above the page bottom. Dragging only works while the
/// button is visible: the drag detector sits inside the button's own
/// [IgnorePointer], so an invisible button never intercepts a drag.
class DraggableBackToTop extends StatefulWidget {
  const DraggableBackToTop({
    super.key,
    required this.controller,
    this.onLongPress,
    this.bottom = 96,
    this.tooltip,
  });

  final ScrollController? controller;
  final VoidCallback? onLongPress;

  /// Bottom distance for the default (not dragged) placement.
  final double bottom;
  final String? tooltip;

  @override
  State<DraggableBackToTop> createState() => _DraggableBackToTopState();
}

class _DraggableBackToTopState extends State<DraggableBackToTop> {
  // Transient pixel position while dragging; null otherwise, in which
  // case the position comes from settings (or the default placement).
  Offset? _dragPos;

  static const _size = 56.0;

  Offset _clamp(Offset pos, Size screen, EdgeInsets padding) => Offset(
        pos.dx.clamp(8.0, screen.width - _size - 8),
        pos.dy.clamp(
            padding.top + 8, screen.height - padding.bottom - _size - 8),
      );

  /// Current pixel position: drag position, saved position, or null for
  /// the default left/right placement.
  Offset? _currentPos(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    if (_dragPos != null) return _clamp(_dragPos!, screen, padding);
    final nx = GStorage.backToTopPosX;
    final ny = GStorage.backToTopPosY;
    if (nx != null && ny != null) {
      return _clamp(
          Offset(nx * screen.width, ny * screen.height), screen, padding);
    }
    return null;
  }

  Offset _defaultPos(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final onLeft = GStorage.backToTopOnLeft;
    return Offset(
      onLeft ? 16 : screen.width - 16 - _size,
      screen.height - widget.bottom - _size,
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      final start = _dragPos ?? _currentPos(context) ?? _defaultPos(context);
      _dragPos = _clamp(
        start + details.delta,
        MediaQuery.sizeOf(context),
        MediaQuery.paddingOf(context),
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final pos = _dragPos;
    if (pos == null) return;
    final screen = MediaQuery.sizeOf(context);
    GStorage.settings.put(SettingsBoxKey.backToTopPosX, pos.dx / screen.width);
    GStorage.settings.put(
        SettingsBoxKey.backToTopPosY, pos.dy / screen.height);
    setState(() => _dragPos = null);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: GStorage.settings.listenable(keys: [
        SettingsBoxKey.backToTopEnabled,
        SettingsBoxKey.backToTopSide,
        SettingsBoxKey.backToTopPosX,
        SettingsBoxKey.backToTopPosY,
      ]),
      builder: (context, _, __) {
        if (!GStorage.backToTopEnabled) {
          return const SizedBox.shrink();
        }
        final pos = _currentPos(context);
        final button = BackToTopAction(
          controller: widget.controller,
          onLongPress: widget.onLongPress,
          onDragUpdate: _onDragUpdate,
          onDragEnd: _onDragEnd,
        );
        final child = widget.tooltip == null
            ? button
            : Tooltip(message: widget.tooltip!, child: button);
        if (pos != null) {
          return Positioned(left: pos.dx, top: pos.dy, child: child);
        }
        final onLeft = GStorage.backToTopOnLeft;
        return Positioned(
          left: onLeft ? 16 : null,
          right: onLeft ? null : 16,
          bottom: widget.bottom,
          child: child,
        );
      },
    );
  }
}

/// Shared back-to-top overlay for list pages other than the home feed
/// (topic, product, search results, installed apps). It honours the same
/// settings as the home feed button (the 回顶键 switch and the left/right
/// position) and sits above the system bottom padding, so it never needs
/// per-page offset bookkeeping like the home feed's publish-button
/// stacking. Long-press refresh is per page: pass [onLongPress] when the
/// page can reload its first page, omit it for tap-to-top-only lists.
/// The button is draggable everywhere: see [DraggableBackToTop].
class BackToTopOverlay extends StatelessWidget {
  const BackToTopOverlay({
    super.key,
    required this.controller,
    this.onLongPress,
  });

  final ScrollController? controller;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return DraggableBackToTop(
      controller: controller,
      onLongPress: onLongPress,
      bottom: MediaQuery.paddingOf(context).bottom + 96,
      tooltip: onLongPress == null ? '回到顶部' : '回到顶部，长按刷新',
    );
  }
}
