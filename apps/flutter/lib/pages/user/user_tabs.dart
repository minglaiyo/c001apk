// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/common_body.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/common/common_controller.dart';

/// 个人主页的标签页。
///
/// 与官方 `UserPagerFragment` 的 `tabType` / `tabTitle` 对齐：
/// `feed`/`rating`/`article`/`question`/`coolpic` → 动态/点评/图文/问答/酷图。
/// 移植自 kongwufang/c001apk_next `pages/user/user_tab.dart`（AGPL-3.0）。
enum UserTabType {
  FEED('动态', 'feed'),
  RATING('点评', 'rating'),
  ARTICLE('图文', 'article'),
  QUESTION('问答', 'question'),
  COOLPIC('酷图', 'coolpic');

  const UserTabType(this.label, this.type);

  final String label;
  final String type;

  /// 该标签的数据是否走 `/v6/page/dataList?url=...`（页面 URL 作为查询参数），
  /// 而不是把路径直接当接口：官方 `getDataList` 是
  /// `@GET("/v6/page/dataList")` + `@Query("url")`。
  bool get viaPageDataList => this == RATING || this == COOLPIC;

  /// 该标签的数据接口（`uid` 必须显式携带，否则服务端按登录用户返回别人的内容）。
  String url(String uid) => switch (this) {
        UserTabType.FEED =>
          '/v6/user/feedList?showAnonymous=0&isIncludeTop=1&showDoing=0&uid=$uid',
        UserTabType.RATING =>
          '/feed/nodeRatingList?uid=$uid&targetType=all&parseRatingToFeed=1',
        UserTabType.ARTICLE => '/v6/user/htmlFeedList?uid=$uid',
        UserTabType.QUESTION => '/v6/user/questionAndAnswerList?uid=$uid',
        UserTabType.COOLPIC =>
          '/feed/userCoolPictureFeedList?fragmentTemplate=flex&uid=$uid',
      };

  /// 点评页独有的实体类型（官方 `entityType == "nodeRating"`）。
  String? get extraEntityType => this == RATING ? 'nodeRating' : null;
}

/// 个人主页某个标签的分页控制器：直接复用 [CommonController] 的分页、
/// 黑名单、点赞与关注能力。
class UserTabController extends CommonController {
  UserTabController({required this.uid, required this.type});

  final String uid;
  final UserTabType type;

  @override
  Future<LoadingState> customGetData() {
    // 「动态」复用已有的 getUserFeed（官方 feedList 的同款参数口径）。
    if (type == UserTabType.FEED) {
      return NetworkRepo.getUserFeed(
        uid: uid,
        page: page,
        firstItem: firstItem,
        lastItem: lastItem,
      );
    }
    if (type.viaPageDataList) {
      return NetworkRepo.getDataList(
        url: type.url(uid),
        title: '',
        subTitle: '',
        firstItem: firstItem,
        lastItem: lastItem,
        page: page,
      );
    }
    return NetworkRepo.getDataListFromUrl(
      url: type.url(uid),
      data: {
        'page': page,
        if (firstItem != null) 'firstItem': firstItem,
        if (lastItem != null) 'lastItem': lastItem,
      },
    );
  }

  @override
  void onInit() {
    super.onInit();
    onGetData();
  }
}

/// 个人主页标签页的内容：分页、下拉刷新、过滤与瀑布流全部复用 [commonBody]。
class UserTabContent extends StatefulWidget {
  const UserTabContent({
    super.key,
    required this.uid,
    required this.type,
    required this.random,
  });

  final String uid;
  final UserTabType type;

  /// 页面级随机段：同一用户页的多个标签共用，避免与其它页面的 tag 冲突。
  final String random;

  @override
  State<UserTabContent> createState() => _UserTabContentState();
}

class _UserTabContentState extends State<UserTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final String _tag = '${widget.uid}-${widget.type.type}-${widget.random}';

  late final UserTabController _controller = Get.put(
    UserTabController(uid: widget.uid, type: widget.type),
    tag: _tag,
  );

  @override
  void initState() {
    super.initState();
    _controller.refreshKey = GlobalKey<RefreshIndicatorState>();
    _controller.scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.scrollController?.dispose();
    Get.delete<UserTabController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return commonBody(_controller);
  }
}
