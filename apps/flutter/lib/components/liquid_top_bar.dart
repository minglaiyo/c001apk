import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/storage_util.dart';
import '../utils/extensions.dart';
import 'basic_glass.dart';
export 'basic_glass.dart' show LiquidGlassButton;

/// Root toolbar surfaces share the navigation glass preference and optics.
/// Keep the body in the same element slot when preferences change.
///
/// The top bar follows the same scroll behaviour as the floating bottom
/// navigation bar: scrolling down (towards newer content) hides the
/// search/tab bar so it does not cover the feed, and scrolling up brings
/// it back. Horizontal tab/page swipes do not hide it.
///
/// Hiding is two-stage so the bar never overflows while it collapses:
/// first the title and actions fade out at full height, then, once they
/// are invisible, the bar height and the body's top inset collapse.
/// Showing runs the same stages in reverse.
class LiquidTopBarScaffold extends StatefulWidget {
  const LiquidTopBarScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onSearch,
    this.actions = const [],
    this.overlayBody = true,
    this.titleSpacing,
    this.glassTitle,
    this.compactTitle = false,
    this.floatWithoutGlass = false,
    this.glassActions,
  });

  final Widget title, body;

  /// Root pages opt in without changing the body element's position.
  final WidgetBuilder? glassTitle;
  final List<Widget> Function(BuildContext context)? glassActions;
  final bool compactTitle, floatWithoutGlass;
  final VoidCallback? onSearch;
  final List<Widget> actions;
  final bool overlayBody;
  final double? titleSpacing;

  @override
  State<LiquidTopBarScaffold> createState() => _LiquidTopBarScaffoldState();
}

class _LiquidTopBarScaffoldState extends State<LiquidTopBarScaffold>
    with SingleTickerProviderStateMixin {
  // 200ms, and rebuilt only through AnimatedBuilder below. The previous
  // version called setState on every animation tick, which rebuilt this
  // whole scaffold and, through the changing body MediaQuery inset, the
  // feed pages below it on every frame - that is what made scrolling feel
  // laggy on a real device with images in the feed.
  late final _barAnimation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200), value: 1);

  @override
  void dispose() {
    _barAnimation.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification notification, bool canHide) {
    if (!canHide || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.direction == ScrollDirection.reverse) {
      _barAnimation.reverse();
    } else if (notification.direction == ScrollDirection.forward) {
      _barAnimation.forward();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: GStorage.settings.listenable(keys: [
          SettingsBoxKey.floatingNavigation,
          SettingsBoxKey.liquidGlass,
          SettingsBoxKey.liquidGlassLevel,
        ]),
        builder: (context, _, __) => AnimatedBuilder(
          animation: _barAnimation,
          // The body widget instance is passed as AnimatedBuilder's child,
          // so animation ticks rebuild only the AppBar and the inset
          // Padding/MediaQuery around it, not the feed pages themselves.
          child: widget.body,
          builder: (context, child) {
            final media = MediaQuery.of(context);
          final glass = widget.glassTitle != null &&
              GStorage.floatingNavigation &&
              (GStorage.liquidGlass || widget.floatWithoutGlass);
          final height = glass
              ? math.max(64.0, media.textScaler.scale(20) + 16)
              : kToolbarHeight;
          // Stage 1 (value 1 -> 0.5): fade out at full height.
          // Stage 2 (value 0.5 -> 0): collapse height with content gone.
          final value = _barAnimation.value;
          final heightFactor = value >= 0.5 ? 1.0 : value * 2.0;
          final opacity = value >= 0.5 ? (value - 0.5) * 2.0 : 0.0;
          final animatedHeight = height * heightFactor;
          final inset = media.padding.top + animatedHeight;
          final overlay = glass && widget.overlayBody;
          final canHide = media.viewInsets.bottom == 0;
          final search = IconButton(
            onPressed: widget.onSearch,
            icon: const Icon(Icons.search),
            tooltip: '搜索',
          );
          // glassTitle is only evaluated when glass is true: the original
          // code only dereferenced it inside the glass branch, and building
          // it eagerly here would crash with a null check when a page does
          // not provide a glass title (glass == false).
          final glassTitle = !glass || opacity == 0
              ? const SizedBox.shrink()
              : Opacity(
                  opacity: opacity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth:
                              widget.compactTitle ? double.infinity : 720),
                      child: Row(children: [
                        Expanded(
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                key: const ValueKey('glass-top-title'),
                                height: height - 16,
                                child: widget.glassTitle!(context),
                              )),
                        ),
                        if (widget.onSearch != null) ...[
                          const SizedBox(width: 10),
                          LiquidGlassButton(
                            key: const ValueKey('glass-search'),
                            level: GStorage.liquidGlassLevel,
                            enabled: GStorage.liquidGlass,
                            tooltip: '搜索',
                            height: height - 16,
                            width: height - 16,
                            onPressed: widget.onSearch!,
                            child: const Center(child: Icon(Icons.search)),
                          ),
                        ],
                        if (widget.glassActions != null)
                          ...widget.glassActions!(context),
                      ]),
                    ),
                  ),
                );
          final plainTitle = opacity == 0
              ? const SizedBox.shrink()
              : Opacity(opacity: opacity, child: widget.title);
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: animatedHeight,
              titleSpacing: glass ? 12 : widget.titleSpacing,
              backgroundColor: glass ? Colors.transparent : null,
              forceMaterialTransparency: glass,
              systemOverlayStyle:
                  glass ? context.fitSystemUiOverlayStyle : null,
              elevation: glass ? 0 : null,
              scrolledUnderElevation: glass ? 0 : null,
              title: glass ? glassTitle : plainTitle,
              actions: glass
                  ? null
                  : opacity == 0
                      ? const []
                      : [
                          for (final action in widget.actions)
                            Opacity(opacity: opacity, child: action),
                          if (widget.onSearch != null)
                            Opacity(opacity: opacity, child: search),
                        ],
            ),
            body: NotificationListener<UserScrollNotification>(
              onNotification: (notification) =>
                  _onScroll(notification, canHide),
              child: Padding(
                padding: EdgeInsets.only(top: overlay ? 0 : inset),
                child: MediaQuery(
                  data: media.copyWith(
                    padding: media.padding.copyWith(top: overlay ? inset : 0),
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          },
        ),
      );
}
