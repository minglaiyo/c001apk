import '../../../pages/home/follow_tabs.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../components/common_body.dart';
import '../../../components/scroll_hide_animator.dart';
import '../../../components/scroll_hiding_action.dart';
import '../../../components/home_publish_action.dart';
import '../../../pages/home/feed/home_feed_controller.dart';
import '../../../pages/home/home_page.dart' show TabType;
import '../../../pages/home/return_top_controller.dart';
import '../../../utils/global_data.dart';
import '../../../utils/storage_util.dart';

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
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final bool isLogin = GlobalData().isLogin;
  StreamSubscription<int>? _returnTopSubscription;

  late final followType = widget.followType ?? GStorage.followType;
  late final _tag = widget.tabType == TabType.FOLLOW
      ? '${widget.tabType.name}-${UniqueKey()}'
      : widget.tabType.name;

  late final _homeFeedController = Get.put(
    HomeFeedController(
      tabType: widget.tabType,
      installTime: GStorage.installTime,
      url: switch (widget.tabType) {
        TabType.FOLLOW => getFollowUrl(followType),
        TabType.HOT => '/page?url=V9_HOME_TAB_RANKING',
        TabType.COOLPIC => '/page?url=V11_FIND_COOLPIC',
        _ => null,
      },
      title: switch (widget.tabType) {
        TabType.FOLLOW => getFollowTitle(followType),
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
    _homeFeedController.scrollController?.dispose();
    Get.delete<HomeFeedController>(
      tag: _tag,
    );
    super.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: GlobalData().isLogin &&
              widget.tabType == TabType.FEED
          ? ScrollHideAnimator(
              scrollController: _homeFeedController.scrollController,
              onVisibilityChanged: widget.onPublishVisibilityChanged,
              builder: (_, animation) => widget.useRail
                  // 侧栏布局由 main 外壳消费显隐状态渲染发布入口，
                  // 这里不重复渲染悬浮按钮。
                  ? const SizedBox.shrink()
                  : ScrollHidingAction(
                      animation: animation,
                      child: const HomePublishAction(),
                    ),
            )
          : null,
      body: commonBody(_homeFeedController),
    );
  }
}
