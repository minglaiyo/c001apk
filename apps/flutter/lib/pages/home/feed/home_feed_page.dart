import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../components/back_to_top_action.dart';
import '../../../components/common_body.dart';
import '../../../components/new_feed_tip.dart';
import '../../../components/scroll_hiding_action.dart';
import '../../../components/home_publish_action.dart';
import '../../../pages/home/feed/home_feed_controller.dart';
import '../../../pages/home/home_page.dart' show TabType;
import '../../../pages/home/return_top_controller.dart';
import '../../../utils/extensions.dart';
import '../../../utils/global_data.dart';
import '../../../utils/storage_util.dart';
import '../../../utils/utils.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({
    super.key,
    required this.tabType,
    this.followType,
    this.useRail = false,
    this.onPublishVisibilityChanged,
  });

  final TabType tabType;
  final int? followType;
  final bool useRail;
  final ValueChanged<bool>? onPublishVisibilityChanged;

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late final bool isLogin = GlobalData().isLogin;
  AnimationController? _fabAnimationCtr;
  StreamSubscription<int>? _returnTopSubscription;
  late bool _isFabVisible = true;

  /// Last capsule opacity built, used only to throttle rebuilds from
  /// the scroll listener. The opacity itself is computed in [build]
  /// from the current scroll offset, so a newly shown capsule always
  /// starts fully visible.
  double _lastTipOpacity = 1;

  late final followType = widget.followType ?? GStorage.followType;
  late final _tag = widget.tabType == TabType.FOLLOW
      ? '${widget.tabType.name}-${UniqueKey()}'
      : widget.tabType.name;

  late final _homeFeedController = Get.put(
    HomeFeedController(
      tabType: widget.tabType,
      installTime: GStorage.installTime,
      url: switch (widget.tabType) {
        TabType.FOLLOW => Utils.getFollowUrl(followType),
        TabType.HOT => '/page?url=V9_HOME_TAB_RANKING',
        TabType.COOLPIC => '/page?url=V11_FIND_COOLPIC',
        _ => null,
      },
      title: switch (widget.tabType) {
        TabType.FOLLOW => Utils.getFollowTitle(followType),
        TabType.HOT => '热榜',
        TabType.COOLPIC => '酷图',
        _ => null,
      },
    ),
    tag: _tag,
  );

  @override
  void dispose() {
    _returnTopSubscription?.cancel();
    _homeFeedController.scrollController?.removeListener(_onTipScroll);
    _homeFeedController.scrollController?.removeListener(() {});
    _homeFeedController.scrollController?.dispose();
    _fabAnimationCtr?.dispose();
    Get.delete<HomeFeedController>(
      tag: _tag,
    );
    super.dispose();
  }

  /// Fades the "更新了 N 条动态" capsule out as the user scrolls down
  /// from the offset where it appeared (fully faded over 300px), and
  /// hides it at 0. Scrolling back up restores it, since the opacity
  /// is computed from the offset in [build].
  void _onTipScroll() {
    if (_homeFeedController.newFeedCount.value == null) return;
    final scrollController = _homeFeedController.scrollController;
    if (scrollController == null || !scrollController.hasClients) return;
    final opacity = (1 -
            (scrollController.offset -
                    _homeFeedController.newFeedTipShownOffset) /
                300)
        .clamp(0.0, 1.0);
    if (opacity <= 0) {
      _homeFeedController.hideNewFeedTip();
    } else if ((opacity - _lastTipOpacity).abs() > 0.02 && mounted) {
      _lastTipOpacity = opacity;
      setState(() {});
    }
  }

  /// Capsule tap: hide the capsule, scroll to top, and refresh the
  /// current tab's first page. The controller suppresses the tip for
  /// this refresh, so the tap-to-hide is not undone when it completes.
  void _onNewFeedTipTap() {
    _homeFeedController.markTipTapRefresh();
    _homeFeedController.scrollController?.animToTop();
    _homeFeedController.onReset();
    _homeFeedController.onGetData();
  }

  @override
  void initState() {
    super.initState();

    _homeFeedController.refreshKey = GlobalKey<RefreshIndicatorState>();
    _homeFeedController.scrollController = ScrollController();
    _homeFeedController.returnTopController =
        Get.find<ReturnTopController>(tag: 'home');

    _returnTopSubscription =
        _homeFeedController.returnTopController?.index.listen((index) {
      if (index == TabType.values.indexOf(widget.tabType)) {
        _homeFeedController.animateToTop();
      }
    });

    _homeFeedController.scrollController?.addListener(_onTipScroll);

    if (isLogin) {
      _fabAnimationCtr = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 300));
      _fabAnimationCtr?.forward();
      _homeFeedController.scrollController?.addListener(() {
        final ScrollDirection? direction =
            _homeFeedController.scrollController?.position.userScrollDirection;
        if (direction == ScrollDirection.forward) {
          _showFab();
        } else if (direction == ScrollDirection.reverse) {
          _hideFab();
        }
      });
    }
  }

  void _showFab() {
    if (!_isFabVisible) {
      _isFabVisible = true;
      _fabAnimationCtr?.forward();
      widget.onPublishVisibilityChanged?.call(true);
    }
  }

  void _hideFab() {
    if (_isFabVisible) {
      _isFabVisible = false;
      _fabAnimationCtr?.reverse();
      widget.onPublishVisibilityChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // The publish button hides while scrolling down, which is exactly when
    // the back-to-top button is needed, so they rarely overlap. When both
    // are visible (scrolling back up but still far from the top), stack the
    // back-to-top button above the publish button instead of on top of it.
    final publishVisible = GlobalData().isLogin &&
        widget.tabType == TabType.FEED &&
        !widget.useRail &&
        _isFabVisible;
    return Scaffold(
      floatingActionButton: GlobalData().isLogin &&
              widget.tabType == TabType.FEED &&
              !widget.useRail
          ? ScrollHidingAction(
              animation: _fabAnimationCtr!,
              child: const HomePublishAction(),
            )
          : null,
      body: Stack(
        children: [
          commonBody(_homeFeedController),
          ValueListenableBuilder(
            valueListenable: GStorage.settings.listenable(keys: [
              SettingsBoxKey.backToTopEnabled,
              SettingsBoxKey.backToTopSide,
            ]),
            builder: (context, _, __) {
              if (!GStorage.backToTopEnabled) {
                return const SizedBox.shrink();
              }
              final onLeft = GStorage.backToTopOnLeft;
              // On the left the publish button (right side) never overlaps,
              // so no extra stacking offset is needed there.
              final bottomOffset = widget.useRail
                  ? 16.0
                  : MediaQuery.paddingOf(context).bottom +
                      (onLeft || !publishVisible ? 96.0 : 164.0);
              return Positioned(
                left: onLeft ? 16 : null,
                right: onLeft ? null : 16,
                bottom: bottomOffset,
                child: Tooltip(
                  message: '回到顶部，长按刷新',
                  child: BackToTopAction(
                    controller: _homeFeedController.scrollController,
                    // TiebaLite long-press semantics: the button itself
                    // scrolls to top, this only reloads the current tab's
                    // first page. Direct reload (not RefreshIndicator.show)
                    // so it works even while the list is still animating
                    // back to the top.
                    onLongPress: () {
                      _homeFeedController.onReset();
                      _homeFeedController.onGetData();
                    },
                  ),
                ),
              );
            },
          ),
          // Floating "更新了 N 条动态" capsule, centred just below the
          // top tab bar, over the list like TiebaLite's TopCenter
          // RefreshTip. It only exists while the controller reports a
          // new-feed count. The scaffold extends the body behind its
          // glass AppBar, so a fixed top of 12 would land the capsule
          // on the status bar and the tab bar itself; the scaffold
          // instead reports the bar height through this MediaQuery
          // padding (status bar + bar height in glass mode, 0 when the
          // body is already padded below a plain AppBar).
          Obx(() {
            final count = _homeFeedController.newFeedCount.value;
            if (count == null) return const SizedBox.shrink();
            final scrollController = _homeFeedController.scrollController;
            final offset = scrollController != null && scrollController.hasClients
                ? scrollController.offset
                : 0.0;
            final opacity = (1 -
                    (offset - _homeFeedController.newFeedTipShownOffset) /
                        300)
                .clamp(0.0, 1.0);
            return Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: NewFeedTip(
                  count: count,
                  opacity: opacity,
                  onTap: _onNewFeedTipTap,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
