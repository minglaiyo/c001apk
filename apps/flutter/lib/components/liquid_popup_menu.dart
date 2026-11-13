import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/storage_util.dart';
import 'liquid_glass_surface.dart';
import 'liquid_top_bar.dart';

/// Keep the existing popup entries and selection behavior inside one glass pane.
class LiquidPopupMenuButton<T> extends StatefulWidget {
  const LiquidPopupMenuButton(
      {super.key,
      required this.child,
      required this.tooltip,
      this.items,
      this.itemBuilder,
      required this.onSelected,
      required this.height,
      required this.width})
      : assert(items != null || itemBuilder != null);

  final Widget child;
  final String tooltip;

  /// Fixed entries, as before.
  final List<PopupMenuEntry<T>>? items;

  /// When given, evaluated when the menu opens (like
  /// `PopupMenuButton.itemBuilder`), so entries that depend on
  /// just-changed state — e.g. a topic page's Sort entry, which flips
  /// with the selected tab without a page rebuild — are always current.
  final PopupMenuItemBuilder<T>? itemBuilder;
  final ValueChanged<T> onSelected;
  final double height, width;

  @override
  State<LiquidPopupMenuButton<T>> createState() =>
      _LiquidPopupMenuButtonState<T>();
}

/// Opens [items] in the existing fake-glass panel (see [_GlassPopupPanel],
/// which is built on `GlassSurface` from `basic_glass.dart`: blur + tint,
/// no shader, no refraction), anchored below [anchorRect] in overlay
/// coordinates. This is the Yuxiximyxx `showGlassMenu` shape adapted to
/// the fork's own panel: fade + scale 0.95→1 on entry (200ms), height
/// capped at 55% of the overlay height, items keep their
/// `PopupMenuEntry` semantics unchanged.
///
/// Note the deltas from the Yuxiximyxx original, kept deliberately:
/// the panel width is the existing fixed 232dp (inside Yuxiximyxx's
/// 168–280dp band) rather than per-item `IntrinsicWidth`, and the exit
/// animation reuses the 200ms entry duration because `showGeneralDialog`
/// exposes no separate reverse duration (Yuxiximyxx used 130ms).
Future<T?> showLiquidMenu<T>({
  required BuildContext context,
  required Rect anchorRect,
  required List<PopupMenuEntry<T>> items,
  required String tooltip,
}) {
  final navigator = Navigator.of(context);
  final media = MediaQuery.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
        child: child,
      ),
    ),
    pageBuilder: (context, _, __) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: media.textScaler,
            highContrast: media.highContrast,
            disableAnimations: media.disableAnimations),
        child: themes.wrap(
          CustomSingleChildLayout(
            delegate: _MenuLayout(anchorRect, MediaQuery.paddingOf(context)),
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                namesRoute: true,
                scopesRoute: true,
                explicitChildNodes: true,
                role: ui.SemanticsRole.menu,
                label: tooltip,
                child: Shortcuts(
                  shortcuts: const <ShortcutActivator, Intent>{
                    SingleActivator(LogicalKeyboardKey.arrowDown):
                        NextFocusIntent(),
                    SingleActivator(LogicalKeyboardKey.arrowUp):
                        PreviousFocusIntent(),
                  },
                  child: FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: Focus(
                      autofocus: true,
                      child: _GlassPopupPanel(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: items),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )),
  );
}

class _LiquidPopupMenuButtonState<T> extends State<LiquidPopupMenuButton<T>> {
  final _anchor = GlobalKey();

  Future<void> _open() async {
    final box = _anchor.currentContext!.findRenderObject()! as RenderBox;
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final anchor = origin & box.size;
    final selected = await showLiquidMenu<T>(
      context: context,
      anchorRect: anchor,
      items: widget.itemBuilder?.call(context) ?? widget.items ?? const [],
      tooltip: widget.tooltip,
    );
    if (mounted && selected != null) widget.onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => LiquidGlassButton(
        key: _anchor,
        height: widget.height,
        width: widget.width,
        enabled: GStorage.liquidGlass,
        level: GStorage.liquidGlassLevel,
        tooltip: widget.tooltip,
        onPressed: _open,
        child: widget.child,
      );
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.anchor, this.padding);
  final Rect anchor;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width =
        math.min(232.0, constraints.maxWidth - padding.horizontal - 16);
    return BoxConstraints.tightFor(width: width).copyWith(
      maxHeight: math.max(
          0,
          math.min(constraints.maxHeight - padding.vertical - 16,
              constraints.maxHeight * 0.55)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = anchor.left.clamp(
        padding.left + 8,
        math.max(padding.left + 8,
            size.width - padding.right - childSize.width - 8));
    final top = (anchor.bottom + 8).clamp(
        padding.top + 8,
        math.max(padding.top + 8,
            size.height - padding.bottom - childSize.height - 8));
    return Offset(left.toDouble(), top.toDouble());
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor || padding != oldDelegate.padding;
}

class _GlassPopupPanel extends StatelessWidget {
  const _GlassPopupPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
      valueListenable: GStorage.settings.listenable(
          keys: [SettingsBoxKey.liquidGlass, SettingsBoxKey.liquidGlassLevel]),
      builder: (context, _, __) => LiquidGlassPanel(
          key: const ValueKey('glass-popup-panel'),
          enabled: GStorage.liquidGlass,
          level: GStorage.liquidGlassLevel,
          borderRadius: BorderRadius.circular(24),
          child: child));
}
