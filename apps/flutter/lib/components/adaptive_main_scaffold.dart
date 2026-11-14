import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/storage_util.dart';
import 'expressive_navigation_bar.dart';
import 'liquid_navigation_bar.dart';
import 'scroll_hiding_action.dart';
import 'package:c001apk_flutter/constants/app_motion.dart';

/// The page subtree stays in the same slot when navigation style or width changes.
///
/// On Android-style narrow layouts the floating bottom navigation bar
/// follows the same scroll behaviour as the floating publish/update buttons:
/// scrolling down (towards newer content) hides it so it does not cover the
/// feed, and scrolling up brings it back. It only applies to the floating
/// bar: the non-floating bar reserves its own space, and the rail/keyboard
/// layouts have no bottom bar to hide.
class AdaptiveMainScaffold extends StatefulWidget {
  const AdaptiveMainScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.bodyBuilder,
    this.railTrailing,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget Function(BuildContext context, bool useRail) bodyBuilder;
  final Widget? railTrailing;

  @override
  State<AdaptiveMainScaffold> createState() => _AdaptiveMainScaffoldState();
}

class _AdaptiveMainScaffoldState extends State<AdaptiveMainScaffold>
    with SingleTickerProviderStateMixin {
  late final _barAnimation = AnimationController(
      vsync: this,
      duration: AppDurations.control,
      reverseDuration: AppDurations.fast,
      value: 1);

  @override
  void dispose() {
    _barAnimation.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification notification, bool canHide) {
    // Only vertical browsing drives the bar. Horizontal tab/page swipes
    // must not hide it, and notifications must keep bubbling to other
    // listeners (for example the reading pane's scroll restoration).
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
        builder: (context, _, __) =>
            LayoutBuilder(builder: (context, constraints) {
          final useRail =
              constraints.maxWidth - MediaQuery.paddingOf(context).horizontal >=
                  600;
          final floating = GStorage.floatingNavigation;
          final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
          final canHide = floating && !useRail && !keyboard;
          return Scaffold(
            // Scaffold inserts a different element tree when extendBody changes.
            // Keep it enabled and reserve the standard bar with stable wrappers so
            // preference/width changes cannot unmount account pages or their scrolls.
            extendBody: true,
            body: NotificationListener<UserScrollNotification>(
              onNotification: (notification) =>
                  _onScroll(notification, canHide),
              child: Builder(builder: (context) {
                final media = MediaQuery.of(context);
                final reserve = !useRail && !keyboard && !floating;
                return Padding(
                  padding:
                      EdgeInsets.only(bottom: reserve ? media.padding.bottom : 0),
                  child: MediaQuery(
                    data: media.copyWith(
                      padding: reserve
                          ? media.padding.copyWith(bottom: 0)
                          : media.padding,
                      // Nested page FABs use viewPadding; lists use padding.
                      viewPadding: !useRail && floating && !keyboard
                          ? media.viewPadding
                              .copyWith(bottom: media.padding.bottom)
                          : media.viewPadding,
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Row(children: [
                        SizedBox(
                        width: useRail ? 144 : 0,
                        child: Offstage(
                          offstage: !useRail,
                          child: !useRail
                              ? const SizedBox.shrink()
                              : Stack(
                                  children: [
                                    Positioned.fill(
                                        child: Center(
                                            child: floating
                                                ? LiquidNavigationBar(
                                                    direction: Axis.vertical,
                                                    selectedIndex: widget
                                                        .selectedIndex,
                                                    onDestinationSelected: widget
                                                        .onDestinationSelected,
                                                    refract:
                                                        GStorage.liquidGlass,
                                                    level: GStorage
                                                        .liquidGlassLevel,
                                                  )
                                                : NavigationRail(
                                                    groupAlignment: 0,
                                                    extended: true,
                                                    minExtendedWidth: 144,
                                                    selectedIndex: widget
                                                        .selectedIndex,
                                                    onDestinationSelected: widget
                                                        .onDestinationSelected,
                                                    labelType:
                                                        NavigationRailLabelType
                                                            .none,
                                                    destinations: const [
                                                      NavigationRailDestination(
                                                          icon: Icon(Icons
                                                              .home_outlined),
                                                          selectedIcon:
                                                              Icon(Icons.home),
                                                          label: Text('主页')),
                                                      NavigationRailDestination(
                                                          icon: Icon(Icons
                                                              .feed_outlined),
                                                          selectedIcon:
                                                              Icon(Icons.feed),
                                                          label: Text('关注')),
                                                      NavigationRailDestination(
                                                          icon: Icon(Icons
                                                              .person_outline),
                                                          selectedIcon: Icon(
                                                              Icons.person),
                                                          label: Text('我的')),
                                                    ],
                                                  ))),
                                    if (widget.railTrailing != null)
                                      Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 16,
                                          child: Center(
                                              child: widget.railTrailing)),
                                  ],
                                ),
                          ),
                        ),
                        Expanded(
                            child: widget.bodyBuilder(context, useRail)),
                      ]),
                    ),
                  ),
                );
              }),
            ),
            bottomNavigationBar: useRail || keyboard
                ? null
                : floating
                    ? ScrollHidingAction(
                        animation: _barAnimation,
                        maintainSize: true,
                        child: AnimatedBuilder(
                          animation: _barAnimation,
                          builder: (context, _) => LiquidNavigationBar(
                            selectedIndex: widget.selectedIndex,
                            onDestinationSelected:
                                widget.onDestinationSelected,
                            refract: GStorage.liquidGlass,
                            level: GStorage.liquidGlassLevel,
                            glow: _barAnimation.value,
                          ),
                        ),
                      )
                    : ExpressiveNavigationBar(
                        selectedIndex: widget.selectedIndex,
                        onDestinationSelected:
                            widget.onDestinationSelected,
                      ),
          );
        }),
      );
}
