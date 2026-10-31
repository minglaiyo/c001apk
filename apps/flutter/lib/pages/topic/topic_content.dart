import 'package:flutter/material.dart' hide SearchController;
import 'package:get/get.dart';

import '../../components/back_to_top_action.dart';
import '../../components/common_body.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/home/return_top_controller.dart';
import '../../pages/topic/discussion_sort_url.dart';
import '../../pages/topic/topic_content_controller.dart';
import '../../pages/topic/topic_order_controller.dart';

class TopicContent extends StatefulWidget {
  const TopicContent({
    super.key,
    required this.random,
    required this.tag,
    required this.id,
    required this.index,
    required this.entityType,
    required this.url,
    required this.title,
  });

  final String random;
  final String? tag;
  final String? id;
  final int index;
  final String entityType;
  final String url;
  final String title;

  @override
  State<TopicContent> createState() => _TopicContentState();
}

class _TopicContentState extends State<TopicContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final _topicController = Get.put(
    TopicContentController(
      url: widget.url,
      title: widget.title,
    ),
    tag: widget.url + widget.title + widget.random,
  );

  late final TopicOrderController? _topicOrderController;

  @override
  void dispose() {
    _topicController.scrollController?.dispose();
    Get.delete<TopicContentController>(
      tag: widget.url + widget.title + widget.random,
    );
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _topicController.refreshKey = GlobalKey<RefreshIndicatorState>();
    _topicController.scrollController = ScrollController();
    _topicController.returnTopController = Get.find<ReturnTopController>(
        tag: (widget.tag ?? widget.id!) + widget.random);

    _topicController.returnTopController?.index.listen((index) {
      if (index == widget.index) {
        _topicController.animateToTop();
      }
    });

    if (_isSortableDiscussion) {
      _topicOrderController = Get.find<TopicOrderController>(
          tag: (widget.tag ?? widget.id!) + widget.random);
      _topicOrderController?.topicSortType.listen((type) {
        if (_isProductDiscussion) {
          _topicController.url =
              productDiscussionSortUrl(widget.id!, type);
        } else {
          _topicController.url =
              topicDiscussionSortUrl(_topicController.url, type);
        }
        _topicController.title = discussionSortLabel(type);
        if (_topicController.loadingState.value is Success) {
          _topicController.animateToTop();
        } else {
          _topicController.setLoadingState(LoadingState.loading());
          _topicController.onGetData();
        }
      });
    }
  }

  bool get _isProductDiscussion =>
      widget.entityType == 'product' && widget.title == '讨论';

  /// 可排序的讨论：产品讨论，或 tab URL 带 topic/tagFeedList
  /// 且 withSortCard=1 的话题讨论。排序入口统一走右上角 ⋮ 菜单，
  /// 不在列表顶部另放排序条。
  bool get _isSortableDiscussion =>
      _isProductDiscussion || isTopicDiscussionUrl(widget.url);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        commonBody(_topicController),
        BackToTopOverlay(
          controller: _topicController.scrollController,
          onLongPress: () {
            _topicController.onReset();
            _topicController.onGetData();
          },
        ),
      ],
    );
  }
}
