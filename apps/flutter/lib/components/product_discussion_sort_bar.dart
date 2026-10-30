import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../pages/topic/topic_order_controller.dart';
import '../pages/topic/topic_page.dart' show TopicSortType;

/// 讨论 tab 顶部的可见排序条，对齐 c001apk_next 的
/// ProductSortHeaderAdapter：默认 / 最新 / 热度三段式，靠右排列。
/// 产品讨论和话题讨论共用此条（c001apk_next 里同一个
/// ProductSortHeaderAdapter 也是两边共用）。
///
/// 它只改 [TopicOrderController.topicSortType]，真正的列表重载走
/// TopicContent 里的监听：产品讨论按 listType 拼 product/feedList
/// 的 URL，话题讨论按 sortField 拼 topic/tagFeedList 的 URL。
/// 产品讨论右上角 ⋮ 菜单里的「排序」和这条排序条用的是同一状态，
/// 互相同步；话题讨论此前没有排序入口，现在只有这条。
class ProductDiscussionSortBar extends StatelessWidget {
  const ProductDiscussionSortBar({
    super.key,
    required this.controller,
  });

  final TopicOrderController controller;

  static const _segments = <TopicSortType, String>{
    TopicSortType.DEFAULT: '默认',
    TopicSortType.DATELINE: '最新',
    TopicSortType.HOT: '热度',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.topicSortType.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SegmentedButton<TopicSortType>(
              showSelectedIcon: false,
              segments: _segments.entries
                  .map((entry) => ButtonSegment<TopicSortType>(
                        value: entry.key,
                        label: Text(entry.value),
                      ))
                  .toList(),
              selected: <TopicSortType>{selected},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty &&
                    selection.first != selected) {
                  controller.setTopicSortType(selection.first);
                }
              },
            ),
          ],
        ),
      );
    });
  }
}
