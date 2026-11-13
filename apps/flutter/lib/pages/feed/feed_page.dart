import '../../utils/share_util.dart';
import '../../components/expressive_refresh_indicator.dart';
import '../../components/expressive_loading_indicator.dart';
// ignore_for_file: constant_identifier_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import '../../components/app_sheet.dart';
import '../../constants/app_motion.dart';
import '../../components/scroll_hide_animator.dart';
import '../../components/confirm_dialog.dart';

import '../../components/cards/feed_reply_card.dart';
import '../../components/content_filter_gate.dart';
import '../../components/content_filter_text.dart';
import '../../logic/content_filter/content_filter_projection.dart';
import '../../logic/content_filter/content_filter_rule.dart';
import '../../logic/model/feed_article/feed_article.dart';
import '../../components/feed_article_body.dart';
import '../../components/footer.dart';
import '../../components/status_views.dart';
import '../../components/sliver_pinned_box_adapter.dart';
import '../../components/cards/feed_card.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/media/feed_media_context.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/feed/feed_change_history_view.dart';
import '../../pages/feed/feed_controller.dart';
import '../../pages/feed/reply/reply_dialog.dart' show ReplyType;
import '../../pages/feed/reply/reply_page.dart';
import '../settings/device_identity_page.dart';
import '../history/history_page.dart';
import '../../utils/device_util.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/markdown_content.dart';
import '../../components/content_export_button.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';

enum FeedMenuItem {
  Copy,
  Share,
  Fav,
  Block,
  Source,
  Report,
  EditHistory,
  FloorJump;

  String get label => switch (this) {
        FeedMenuItem.Copy => '复制',
        FeedMenuItem.Share => '分享',
        FeedMenuItem.Fav => '收藏',
        FeedMenuItem.Block => '屏蔽',
        FeedMenuItem.Source => '查看原文',
        FeedMenuItem.Report => '举报',
        FeedMenuItem.EditHistory => '编辑记录',
        FeedMenuItem.FloorJump => '跳楼层',
      };
}

enum ReplySortType { def, dateline, hot, author }

class FeedPage extends StatefulWidget {
  const FeedPage({super.key, this.id, this.onClose});

  final String? id;
  final VoidCallback? onClose;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final String _id = widget.id ?? Get.parameters['id'].orEmpty;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  late final _scrollController = ScrollController();
  // One key per reply card, by list index, so floor jumps can
  // Scrollable.ensureVisible the target card. Indices are stable:
  // pagination only appends, and a refresh rebuilds the same index
  // positions for the new sort order.
  final _replyKeys = <int, GlobalKey>{};
  final _titleVisible = ValueNotifier<bool>(false);
  bool _showSource = false;

  bool get _hasMarkdown {
    final state = _feedController.feedState.value;
    if (state is! Success) return false;
    final data = state.response as Datum;
    return MarkdownContent.parse(data.message.orEmpty).isMarkdown ||
        (_feedController.articleList ?? []).any((part) =>
            part.type == 'text' &&
            MarkdownContent.parse(part.message.orEmpty).isMarkdown);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleVisible.dispose();
    _scrollController.dispose();
    Get.delete<FeedController>(tag: _id + _random);
    super.dispose();
  }

  late final String _random = DeviceUtil.randHexString(8);
  late final _feedController = Get.put(
    FeedController(
      id: _id,
      recordHistory: GStorage.recordHistory,
    ),
    tag: _id + _random,
  );

  static const List<(ReplySortType, String)> _shirtSizeOptions =
      <(ReplySortType, String)>[
    (ReplySortType.def, '默认'),
    (ReplySortType.dateline, '最新'),
    (ReplySortType.hot, '热门'),
    (ReplySortType.author, '楼主'),
  ];

  /// B 层离线快照（详情-only）：断网时若有本动态的快照，
  /// 在错误页上方展示并明确标注保存时间，绝不冒充新鲜内容。
  Widget _buildErrorWithSnapshot(LoadingState feedState, Widget errorBody) {
    Datum? snapshotDatum;
    String? savedText;
    var hasSnapshot = false;
    var snapshotBroken = false;
    try {
      final snapshot = GStorage.getFeedSnapshot(_id);
      hasSnapshot = snapshot != null;
      final json = snapshot?['json'];
      final savedAt = snapshot?['savedAt'];
      if (json is Map) {
        snapshotDatum = Datum.fromJson(Map<String, dynamic>.from(json));
      }
      if (hasSnapshot && snapshotDatum == null) snapshotBroken = true;
      if (savedAt is num) {
        final date =
            DateTime.fromMillisecondsSinceEpoch(savedAt.toInt());
        savedText =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      snapshotDatum = null;
    }
    if (snapshotDatum == null) {
      // Never silently show only the guidance buttons: tell the user
      // whether a snapshot exists at all. Previously a parse failure
      // here was swallowed and the page looked blank of content.
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            errorBody,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                snapshotBroken
                    ? '离线快照已保存但无法读取，请联网重试。'
                    : '无离线快照：该条详情此前未成功加载过，联网后打开一次即可离线查看。',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              '离线内容 · 保存于 ${savedText ?? '未知时间'}，可能不是最新内容',
              textAlign: TextAlign.center,
            ),
          ),
          FeedCard(
            data: snapshotDatum,
            isFeedContent: true,
            forcePlain: _showSource,
          ),
          errorBody,
        ],
      ),
    );
  }

  Widget _buildFeedContent(LoadingState feedState) {
    switch (feedState) {
      case Empty():
        return GestureDetector(
          onTap: () {
            _feedController.setFeedState(LoadingState.loading());
            _feedController.getFeedData();
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10.0),
            child: const Text('暂无内容'),
          ),
        );
      case Error():
        return _buildErrorWithSnapshot(
            feedState,
            Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(feedState.errMsg, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('加载失败时，本地收藏与浏览历史仍可离线查看',
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Get.toNamed('/history',
                        arguments: {'type': HistoryType.Favorite}),
                    child: const Text('本地收藏'),
                  ),
                  TextButton(
                    onPressed: () => Get.toNamed('/history',
                        arguments: {'type': HistoryType.History}),
                    child: const Text('浏览历史'),
                  ),
                ]),
            const SizedBox(height: 12),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () {
                      _feedController.setFeedState(LoadingState.loading());
                      _feedController.getFeedData(verify: true);
                    },
                    child: const Text('重试'),
                  ),
                  if (feedState.canVerify)
                    TextButton(
                      onPressed: () async {
                        final previousDevice = GStorage.xAppDevice;
                        await Get.to(() => const DeviceIdentityPage());
                        if (!mounted || previousDevice == GStorage.xAppDevice) {
                          return;
                        }
                        _feedController.setFeedState(LoadingState.loading());
                        await _feedController.getFeedData();
                      },
                      child: const Text('设备标识设置'),
                    ),
                ]),
          ]),
            ));
      case Success():
        return _feedController.articleList.isNullOrEmpty
            ? FeedCard(
                data: feedState.response!,
                isFeedContent: true,
                forcePlain: _showSource,
                onLike: (id, like) {
                  if (GlobalData().isLogin) {
                    _feedController.onLike(
                      id,
                      like,
                      isFeed: true,
                    );
                  }
                },
              )
            : SliverList.separated(
                itemCount: _feedController.articleList!.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return header(
                      context,
                      feedState.response!,
                      true,
                    );
                  } else if (index == _feedController.articleList!.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: bottomInfo(
                        context,
                        feedState.response!,
                        true,
                        null,
                        isFeedArticle: true,
                        () {
                          if (GlobalData().isLogin) {
                            Datum data = feedState.response;
                            _feedController.onLike(
                              data.id,
                              data.userAction?.like,
                              isFeed: true,
                            );
                          }
                        },
                      ),
                    );
                  } else {
                    return LayoutBuilder(builder: (_, constraints) {
                      final article = _feedController.articleList![index - 1];
                      return ContentFilterText(
                          key: ValueKey('article:$_id:$index'),
                          source: article.type == 'title' ||
                                  article.type == 'shareUrl'
                              ? article.title.orEmpty
                              : article.type == 'image'
                                  ? article.description.orEmpty
                                  : article.message.orEmpty,
                          builder: (message) => feedArticleBody(
                                constraints.maxWidth,
                                FeedArticle.fromJson({
                                  ...article.toJson(),
                                  if (article.type == 'title' ||
                                      article.type == 'shareUrl')
                                    'title': message
                                  else if (article.type == 'image')
                                    'description': message
                                  else
                                    'message': message
                                }),
                                _feedController.articleImgList!,
                                forcePlain: _showSource,
                                mediaItems: mediaForDatum(feedState.response!),
                                contentId: feedState.response!.id?.toString(),
                              ));
                    });
                  }
                },
                separatorBuilder: (_, index) => const SizedBox(height: 12),
              );
    }
    return const ExpressiveLoadingIndicator();
  }

  Future<void> _showAccountDetailStatus() async {
    final retry = await showConfirmDialog(
      context: context,
      title: '账号信息暂不可用',
      content: _feedController.accountDetailNotice.value,
      confirmLabel: '重试账号详情',
      cancelLabel: '关闭',
    );
    if (!retry || !mounted) return;
    await _feedController.getFeedData(verify: true);
    if (!mounted) return;
    final notice = _feedController.accountDetailNotice.value;
    SmartDialog.showToast(notice.isEmpty ? '账号详情已更新' : notice);
  }

  Widget _buildPinWidget() {
    return SliverPinnedBoxAdapter(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Text('共 ${_feedController.replyNum} 回复'),
                  ),
                  Obx(
                    () => SegmentedButton<ReplySortType>(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                      showSelectedIcon: false,
                      selected: <ReplySortType>{
                        _feedController.replySelection.value
                      },
                      segments: _shirtSizeOptions
                          .map<ButtonSegment<ReplySortType>>(
                              ((ReplySortType, String) shirt) {
                        return ButtonSegment<ReplySortType>(
                            value: shirt.$1, label: Text(shirt.$2));
                      }).toList(),
                      onSelectionChanged: (Set<ReplySortType> newSelection) {
                        _feedController.replySelection.value =
                            newSelection.first;
                        switch (newSelection.first) {
                          case ReplySortType.def:
                            _feedController.listType = 'lastupdate_desc';
                            _feedController.fromFeedAuthor = 0;
                            break;
                          case ReplySortType.dateline:
                            _feedController.listType = 'dateline_desc';
                            _feedController.fromFeedAuthor = 0;
                            break;
                          case ReplySortType.hot:
                            _feedController.listType = 'popular';
                            _feedController.fromFeedAuthor = 0;
                            break;
                          case ReplySortType.author:
                            _feedController.listType = '';
                            _feedController.fromFeedAuthor = 1;
                            break;
                        }
                        _refreshKey.currentState?.show();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }

  Future<void> _onReply(
    ReplyType type,
    dynamic id,
    dynamic uname,
    dynamic fid,
  ) async {
    showBottomSheetPage(
      context: context,
      page: ReplyPage(
        type: type,
        username: uname,
        id: id,
      ),
    ).then(
      (result) {
        if (result != null && result['data'] != null) {
          _feedController.updateReply(
            type == ReplyType.reply,
            result['data'] as Datum,
            id,
            fid,
          );
        }
      },
    );
  }

  Widget _buildDeferredReplyPrompt(LoadingState replyState,
      {bool hasReplies = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined),
          const SizedBox(height: 12),
          Text(hasReplies ? '评论加载已暂停' : '评论尚未加载'),
          const SizedBox(height: 8),
          const Text(
            '设备标识尚未取得（可能离线或取号失败），加载评论可能需要验证码验证。'
            '可在设置中自动获取或手动导入后再加载。',
            textAlign: TextAlign.center,
          ),
          if (replyState is Error) ...[
            const SizedBox(height: 8),
            Text(replyState.errMsg, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _feedController.loadReplies,
            icon: const Icon(Icons.download_outlined),
            label: const Text('加载评论并验证'),
          ),
        ],
      ),
    );
  }

  /// Floor navigation, modelled on TiebaLite's thread comment navigation:
  /// jump to a given floor, or to the last floor, in the current sort
  /// order. Floors count reply cards from 1 (the first card in the
  /// current list, pinned reply included); the total comes from the
  /// detail's reply count when known. Arriving at the target gives a
  /// medium haptic, like TiebaLite's last-floor feedback.
  Future<void> _showFloorJumpDialog() async {
    final replyState = _feedController.loadingState.value;
    if (_feedController.repliesDeferred.value || replyState is! Success) {
      SmartDialog.showToast('请先加载评论');
      return;
    }
    final total = _feedController.replyNum;
    final input = TextEditingController();
    // -1 = last floor, chosen by the 末楼 button.
    final floor = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳楼层'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (total != null) Text('共 $total 条评论，按当前排序计数'),
            TextField(
              controller: input,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '输入楼层，如 42',
              ),
              onSubmitted: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null && parsed > 0) {
                  Navigator.of(context).pop(parsed);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(-1),
            child: const Text('末楼'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(input.text);
              if (parsed != null && parsed > 0) {
                Navigator.of(context).pop(parsed);
              }
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    input.dispose();
    if (floor == null || !mounted) return;
    await _jumpToFloor(floor);
  }

  int get _loadedReplyCount {
    final state = _feedController.loadingState.value;
    if (state is! Success) return 0;
    return (state.response as List).length;
  }

  Future<void> _jumpToFloor(int floor) async {
    // Wait out a footer auto-load already in progress, briefly.
    for (var wait = 0;
        _feedController.isLoading && wait < 50 && mounted;
        wait++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    // Load pages until the target floor is loaded, or until the end
    // for the last floor. A load that grows nothing (error / paused)
    // breaks the loop instead of spinning.
    var guard = 0;
    if (floor == -1) {
      while (!_feedController.isEnd && guard++ < 200 && mounted) {
        final before = _loadedReplyCount;
        await _feedController.onGetData(false);
        if (_loadedReplyCount == before) break;
      }
      floor = _loadedReplyCount;
    } else {
      while (_loadedReplyCount < floor &&
          !_feedController.isEnd &&
          guard++ < 200 &&
          mounted) {
        final before = _loadedReplyCount;
        await _feedController.onGetData(false);
        if (_loadedReplyCount == before) break;
      }
      if (floor > _loadedReplyCount) {
        if (!mounted) return;
        SmartDialog.showToast('只有 $_loadedReplyCount 条评论，已定位到末楼');
        floor = _loadedReplyCount;
      }
    }
    if (floor <= 0 || !mounted) return;
    // The target card may not be built yet (a lazy sliver far below the
    // viewport): scroll toward the bottom until it builds, then reveal
    // it precisely.
    for (var attempt = 0; attempt < 25; attempt++) {
      if (!mounted) return;
      final target = _replyKeys[floor - 1]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 400),
          alignment: 0.1,
        );
        await HapticFeedback.mediumImpact();
        return;
      }
      if (!_scrollController.hasClients) return;
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) SmartDialog.showToast('未能定位到第 $floor 楼');
  }

  Widget _buildFeedReply(LoadingState replyState) {
    if (_feedController.repliesDeferred.value && replyState is! Success) {
      return SliverToBoxAdapter(child: _buildDeferredReplyPrompt(replyState));
    }
    switch (replyState) {
      case Empty():
        return const SliverToBoxAdapter(child: EmptyStatusView());
      case Error():
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(replyState.errMsg, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _feedController.loadReplies,
                child: const Text('重新加载评论'),
              ),
            ]),
          ),
        );
      case Success():
        List<Datum> dataList = replyState.response;
        return SliverPadding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          sliver: SliverList.separated(
            itemCount: dataList.length + 1,
            itemBuilder: (_, index) {
              if (index == dataList.length) {
                if (!_feedController.repliesDeferred.value &&
                    !_feedController.isEnd &&
                    !_feedController.automaticLoadPaused &&
                    !_feedController.isLoading) {
                  _feedController.setFooterState(LoadingState.loading());
                  _feedController.onGetData(false);
                }
                return Obx(
                  () => _feedController.repliesDeferred.value
                      ? _buildDeferredReplyPrompt(
                          _feedController.footerState.value,
                          hasReplies: true)
                      : footerWidget(
                          _feedController.footerState.value,
                          () {
                            _feedController
                              ..isEnd = false
                              ..setFooterState(LoadingState.loading())
                              ..onGetData(false);
                          },
                        ),
                );
              } else {
                return FeedReplyCard(
                  key: _replyKeys.putIfAbsent(index, () => GlobalKey()),
                  data: dataList[index],
                  isTopReply: _feedController.topReply != null &&
                      index == 0 &&
                      _feedController.listType == 'lastupdate_desc',
                  onBlock: _feedController.onBlockReply,
                  onReply: (id, uname, fid) {
                    if (GlobalData().isLogin) {
                      _onReply(ReplyType.reply, id, uname, fid);
                    }
                  },
                  onDelete: (id, fid) {
                    _feedController.postLikeDeleteFollow(id, fid,
                        isReply: true);
                  },
                  onLike: (id, like) {
                    _feedController.onLike(id, like, isReply: true);
                  },
                );
              }
            },
            separatorBuilder: (_, index) => const Divider(height: 1),
          ),
        );
    }
    return const SliverToBoxAdapter(child: LoadingStatusView());
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = _feedController.feedState.value;
      if (state is! Success) return _buildScreen(context);
      final data = state.response as Datum;
      return ContentFilterRevealScope(
        contentKeys: _feedController.revealedContentKeys,
        authorUids: _feedController.revealedAuthorUids,
        child: ContentFilterGate(
            data: data,
            scope: FilterScope.feed,
            page: true,
            onClose: widget.onClose,
            onReveal: () => _feedController.revealItem(data),
            builder: _buildScreen),
      );
    });
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      floatingActionButton: Obx(
        () => _feedController.feedState.value is Success && GlobalData().isLogin
            ? ScrollHideAnimator(
                scrollController: _scrollController,
                builder: (context, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 2),
                    end: const Offset(0, 0),
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: AppCurves.scrollHide,
                  )),
                  child: FloatingActionButton(
                    heroTag: null,
                    tooltip: '回复',
                    onPressed: () {
                      _onReply(
                        ReplyType.feed,
                        _feedController.id,
                        _feedController.feedUsername,
                        null,
                      );
                    },
                    child: const Icon(Icons.reply),
                  ),
                ),
              )
            : const SizedBox(),
      ),
      appBar: PreferredSize(
        preferredSize: const Size(double.infinity, 56),
        child: Obx(
          () => AppBar(
            leading: widget.onClose == null
                ? null
                : BackButton(onPressed: widget.onClose),
            titleSpacing: 0,
            title: ValueListenableBuilder<bool>(
              valueListenable: _titleVisible,
              builder: (context, visible, _) {
                return GestureDetector(
                  onTap: () {
                    if (_scrollController.hasClients &&
                        _scrollController.offset != 0) {
                      _scrollController.animToTop();
                    }
                  },
                  child: Container(
                    color: Colors.transparent,
                    width: double.infinity,
                    child: switch (_feedController.feedState.value) {
                      Success(:final response) when visible => header(
                        context,
                        response,
                        true,
                        isHeader: true,
                      ),
                      Success() => Text(
                        _feedController.feedTypeName!,
                        textAlign: Platform.isIOS
                            ? TextAlign.center
                            : TextAlign.start,
                      ),
                      _ => null,
                    },
                  ),
                );
              },
            ),
            actions: switch (_feedController.feedState.value) {
              Success(:final response, :final isPublic) => [
                    if (isPublic && GlobalData().isLogin)
                      IconButton(
                        tooltip: '账号信息暂不可用',
                        onPressed: _feedController.isLoadingDetail.value
                            ? null
                            : _showAccountDetailStatus,
                        icon: _feedController.isLoadingDetail.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: ExpressiveLoadingIndicator(size: 20),
                              )
                            : const Icon(Icons.info_outline),
                      ),
                    ContentExportButton(
                      feed: response as Datum,
                      articles: _feedController.articleList ?? const [],
                    ),
                    PopupMenuButton(
                      onSelected: (FeedMenuItem item) {
                        switch (item) {
                          case FeedMenuItem.Copy:
                            Utils.copyText(
                                getShareUrl(_id, ShareType.feed));
                            break;
                          case FeedMenuItem.Share:
                            final data = response;
                            shareContent(_id, ShareType.feed,
                                title:
                                    data.messageTitle?.trim().isNotEmpty == true
                                        ? data.messageTitle
                                        : data.title,
                                message: ContentFilterProjection.displayMessage(
                                    data),
                                context: context);
                            break;
                          case FeedMenuItem.Fav:
                            if (_feedController.isFav) {
                              GStorage.onDeleteFeed(_id, isHistory: false);
                            } else {
                              _feedController.onFav();
                            }
                            _feedController.isFav = !_feedController.isFav;
                            break;
                          case FeedMenuItem.Block:
                            GStorage.onBlock(
                              _feedController.feedUid.toString(),
                              isDelete: _feedController.isBlocked,
                            );
                            _feedController.isBlocked =
                                !_feedController.isBlocked;
                            break;
                          case FeedMenuItem.Report:
                            if (Utils.isSupportWebview()) {
                              report(_id, ReportType.Feed);
                            } else {
                              SmartDialog.showToast('当前平台暂不支持此功能');
                            }
                            break;
                          case FeedMenuItem.Source:
                            setState(() => _showSource = !_showSource);
                            break;
                          case FeedMenuItem.EditHistory:
                            showFeedChangeHistoryDialog(context, _id);
                            break;
                          case FeedMenuItem.FloorJump:
                            _showFloorJumpDialog();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => FeedMenuItem.values
                          .where((item) =>
                              item != FeedMenuItem.Source || _hasMarkdown)
                          .map((item) => PopupMenuItem<FeedMenuItem>(
                                value: item,
                                child: item == FeedMenuItem.Fav
                                    ? Text(
                                        _feedController.isFav ? '取消收藏' : '收藏',
                                      )
                                    : item == FeedMenuItem.Block
                                        ? Text(
                                            _feedController.isBlocked
                                                ? '取消屏蔽'
                                                : '屏蔽',
                                          )
                                        : item == FeedMenuItem.Source
                                            ? Text(
                                                _showSource ? '格式化显示' : '查看原文')
                                            : Text(item.label),
                              ))
                          .toList(),
                    )
                  ],
                  _ => null,
                },
          ),
        ),
      ),
      body: Obx(
        () => _feedController.feedState.value is Success
            ? ExpressiveRefreshIndicator(
                notificationPredicate: (notification) {
                  if (notification.depth != 0 ||
                      notification.metrics.axis != Axis.vertical) {
                    return false;
                  }
                  final double offset = notification.metrics.pixels;
                  _titleVisible.value = offset > 50;
                  return true;
                },
                refreshKey: _refreshKey,
                onRefresh: () async {
                  _feedController.onReset();
                  await _feedController.onGetData();
                },
                child: CustomScrollView(
                  key: PageStorageKey('feed-reading:$_id'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    _feedController.articleList.isNullOrEmpty
                        ? SliverToBoxAdapter(
                            child: _buildFeedContent(
                                _feedController.feedState.value))
                        : _buildFeedContent(_feedController.feedState.value),
                    _buildPinWidget(),
                    _buildFeedReply(_feedController.loadingState.value),
                  ],
                ),
              )
            : Center(child: _buildFeedContent(_feedController.feedState.value)),
      ),
    );
  }
}
