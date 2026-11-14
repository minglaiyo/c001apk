import '../../utils/share_util.dart';
import '../../components/expressive_refresh_indicator.dart';
import '../../components/expressive_loading_indicator.dart';
// ignore_for_file: constant_identifier_names

import 'dart:math';

import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../components/cards/user_info_card.dart';
import '../../components/content_filter_gate.dart';
import '../../components/sticky_sliver_to_box_adapter.dart';
import '../../logic/content_filter/content_filter_rule.dart';
import '../../components/footer.dart';
import '../../components/status_views.dart';
import '../../components/item_card.dart';
import '../../components/adaptive_card_list.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/user/user_controller.dart';
import '../../pages/user/user_tabs.dart';
import '../../utils/device_util.dart';
import '../../utils/extensions.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';

/// 去除多行字符串中每行 `|` 之前的缩进（替代 package:indent 的 trimMargin）。
extension _StringTrimMargin on String {
  String trimMargin() => split('\n')
      .map((line) {
        final index = line.indexOf('|');
        return index == -1 ? line.trim() : line.substring(index + 1);
      })
      .join('\n');
}

enum UserMenuItem {
  Copy,
  Share,
  Block,
  Report,
  UserInfo;

  String get label => switch (this) {
        UserMenuItem.Copy => '复制',
        UserMenuItem.Share => '分享',
        UserMenuItem.Block => '屏蔽',
        UserMenuItem.Report => '举报',
        UserMenuItem.UserInfo => '用户信息',
      };
}

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage>
    with TickerProviderStateMixin {
  final String _uid = Get.parameters['uid'].orEmpty;
  late final ScrollController _scrollController =
      _userController.scrollController ??= ScrollController();

  late final String _random = DeviceUtil.randHexString(8);
  late final UserController _userController = Get.put(
    UserController(uid: _uid),
    tag: _uid + _random,
  );
  late final TabController _tabController =
      TabController(length: UserTabType.values.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    _userController.scrollController?.dispose();
    Get.delete<UserController>(
      tag: _uid + _random,
    );
    super.dispose();
  }

  Widget _buildUserInfo(LoadingState userState) {
    switch (userState) {
      case Empty():
        return GestureDetector(
          onTap: () {
            _userController.setUserState(LoadingState.loading());
            _userController.onGetUserData();
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10.0),
            child: const Text('暂无内容'),
          ),
        );
      case Error():
        return GestureDetector(
          onTap: () {
            _userController.setUserState(LoadingState.loading());
            _userController.onGetUserData();
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10.0),
            child: Text(userState.errMsg),
          ),
        );
      case Success():
        return UserInfoCard(
          data: userState.response!,
          onFollow: _userController.onFollow,
          onLocalFollow: _userController.onLocalFollow,
        );
    }
    return const ExpressiveLoadingIndicator();
  }

  /// 「动态」标签：沿用本页 UserController 的列表，包成独立滚动视图。
  Widget _userFeedView(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [_buildUserFeed(_userController.loadingState.value)],
    );
  }

  Widget _buildUserFeed(LoadingState loadingState) {
    switch (loadingState) {
      case Empty():
        return SliverToBoxAdapter(
          child: EmptyStatusView(
            onTap: () {
              _userController.setLoadingState(LoadingState.loading());
              _userController.onGetData();
            },
          ),
        );
      case Error():
        return SliverToBoxAdapter(
          child: ErrorStatusView(
            message: loadingState.errMsg,
            onTap: _userController.isBlocked
                ? null
                : () {
                    _userController.setLoadingState(LoadingState.loading());
                    _userController.onGetData();
                  },
          ),
        );
      case Success():
        List<Datum> dataList = loadingState.response as List<Datum>;
        return AdaptiveCardList.sliver(
          padding: EdgeInsets.only(
              left: 10,
              top: 10,
              right: 10,
              bottom: 10 + MediaQuery.of(context).padding.bottom),
          itemCount: dataList.length + 1,
          isFullWidth: (index) =>
              index == dataList.length || dataList[index].entityType != 'feed',
          onLoadMore: () {
            if (!_userController.isEnd &&
                !_userController.isLoading &&
                !_userController.automaticLoadPaused) {
              _userController.setFooterState(LoadingState.loading());
              _userController.onGetData(false);
            }
          },
          itemBuilder: (_, index) {
            if (index == dataList.length) {
              return Obx(
                () => footerWidget(
                  _userController.footerState.value,
                  () {
                    _userController.isEnd = false;
                    _userController.setFooterState(LoadingState.loading());
                    _userController.onGetData(false);
                  },
                ),
              );
            } else {
              return itemCard(
                dataList[index],
                onBlock: _userController.onBlock,
              );
            }
          },
        );
    }
    return const SliverToBoxAdapter(child: LoadingStatusView());
  }

  @override
  Widget build(BuildContext context) {
    return ContentFilterRevealScope(
      contentKeys: _userController.revealedContentKeys,
      authorUids: _userController.revealedAuthorUids,
      child: ContentFilterGate(
        data: Datum(entityType: 'user', id: _uid, uid: _uid),
        scope: FilterScope.user,
        page: true,
        onReveal: () {
          _userController.revealAuthorForPage(_uid);
        },
        builder: _buildScreen,
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Obx(
            () => ExpressiveRefreshIndicator(
              notificationPredicate: (notification) {
                final double offset = notification.metrics.pixels;
                if (offset >= 0) {
                  final ratio = min(1.0, offset / 105);
                  // 顶栏透明度不能在布局期同步触发重建（NestedScrollView +
                  // TabBarView 下会「Build scheduled during frame」），
                  // 改到帧后提交。
                  if (_userController.scrollRatio.value != ratio) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _userController.scrollRatio.value = ratio;
                    });
                  }
                }
                return notification.depth == 0;
              },
              onRefresh: () async {
                if (!_userController.isBlocked ||
                    _userController.revealedAuthorUids.contains(_uid)) {
                  _userController.onReset();
                  await _userController.onGetData();
                } else {
                  return Future.value();
                }
              },
              child: _userController.userState.value is Success
                  ? ExtendedNestedScrollView(
                      key: PageStorageKey('user-reading:$_uid'),
                      controller: _scrollController,
                      onlyOneScrollInBody: true,
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(
                            child: _buildUserInfo(
                                _userController.userState.value),
                          ),
                          SliverOverlapAbsorber(
                            handle: ExtendedNestedScrollView
                                .sliverOverlapAbsorberHandleFor(context),
                            sliver: StickySliverToBoxAdapter(
                              child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  tabs: [
                                    for (final type in UserTabType.values)
                                      Tab(text: type.label),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                      body: LayoutBuilder(builder: (context, _) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: ExtendedNestedScrollView
                                        .sliverOverlapAbsorberHandleFor(
                                            context)
                                    .layoutExtent ??
                                0,
                          ),
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // 「动态」沿用本页已加载的 UserController 列表，
                              // 其余四个标签各自分页。
                              _userFeedView(context),
                              for (final type in UserTabType.values.skip(1))
                                UserTabContent(
                                  uid: _uid,
                                  type: type,
                                  random: _random,
                                ),
                            ],
                          ),
                        );
                      }),
                    )
                  : Center(
                      child: _buildUserInfo(_userController.userState.value),
                    ),
            ),
          ),
          _header(),
        ],
      ),
    );
  }

  Widget _header() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Obx(
        () => AppBar(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: _userController.scrollRatio.value),
          title: _userController.scrollRatio.value == 1 &&
                  _userController.username != null
              ? Text(_userController.username!)
              : null,
          
          actions: _userController.userState.value is Success
              ? [
                  if (!_userController.isBlocked)
                    IconButton(
                      onPressed: () => Get.toNamed('/search', parameters: {
                        'title': _userController.username!,
                        'pageType': 'user',
                        'pageParam': _userController.uid,
                      }),
                      icon: const Icon(Icons.search),
                      tooltip: '搜索',
                    ),
                  PopupMenuButton(
                    onSelected: (UserMenuItem item) {
                      switch (item) {
                        case UserMenuItem.Copy:
                          Utils.copyText(getShareUrl(
                              _userController.uid, ShareType.u));
                          break;
                        case UserMenuItem.Share:
                          shareContent(_userController.uid, ShareType.u,
                              title: _userController.username,
                              context: context);
                          break;
                        case UserMenuItem.Block:
                          GStorage.onBlock(
                            _userController.uid,
                            isDelete: _userController.isBlocked,
                          );
                          if (!_userController.isBlocked) {
                            _userController.setBlockedLoaidngState();
                          }
                          _userController.isBlocked =
                              !_userController.isBlocked;
                          break;
                        case UserMenuItem.Report:
                          report(_userController.uid, ReportType.User);
                          break;
                        case UserMenuItem.UserInfo:
                          showDialog<void>(
                            context: context,
                            builder: (BuildContext context) {
                              Datum user =
                                  (_userController.userState.value as Success)
                                      .response;
                              return AlertDialog(
                                title: Text(
                                  user.username ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                content: Text(
                                  '''
                                      |uid: ${user.uid}\n
                                      |等级: Lv.${user.level}\n
                                      |性别: ${user.gender == 1 ? '男' : user.gender == 0 ? '女' : '未知'}\n
                                      |注册时长: ${(DateTime.now().microsecondsSinceEpoch ~/ 10e5 - user.regdate!) ~/ 24 ~/ 3600} 天\n
                                      |注册时间: ${DateFormat('yyyy年MM月dd日 HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(user.regdate * 1000))}
                                      '''
                                      .trimMargin(),
                                ),
                              );
                            },
                          );
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => UserMenuItem.values
                        .map((item) => PopupMenuItem<UserMenuItem>(
                              value: item,
                              child: item == UserMenuItem.Block
                                  ? Text(
                                      _userController.isBlocked ? '取消屏蔽' : '屏蔽',
                                    )
                                  : Text(item.label),
                            ))
                        .toList(),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
