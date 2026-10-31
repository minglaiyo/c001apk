import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../pages/home/topic/controller.dart';
import '../../../pages/home/home_page.dart' show TabType;
import 'topic_grid_page.dart';

class HomeTopicPage extends StatefulWidget {
  const HomeTopicPage({super.key, required this.tabType});

  final TabType tabType;

  @override
  State<HomeTopicPage> createState() => _HomeTopicPageState();
}

class _HomeTopicPageState extends State<HomeTopicPage>
    with AutomaticKeepAliveClientMixin {
  late HomeTopicController _homeTopicController;
  late PageController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller =
        PageController(initialPage: widget.tabType == TabType.TOPIC ? 1 : 0);
    _homeTopicController = Get.put(
      HomeTopicController(tabType: widget.tabType),
      tag: widget.tabType.name,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    Get.delete<HomeTopicController>(
      tag: widget.tabType.name,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _homeTopicController.obx(
      (data) {
        return Row(
          children: [
            Expanded(
              flex: 22,
              child: Column(
                children: [
                  // Current-page readout: the left list holds the current
                  // top tab's sub-categories, not a second top-level
                  // navigation. Without it, the top pill and the left
                  // highlight read as two peer selections, and both
                  // sections happen to default to a sub-category named
                  // 热门, which makes it look like the same page.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Obx(
                      () {
                        final count = widget.tabType == TabType.TOPIC
                            ? data![0].entities!.length
                            : data!.length;
                        final section = widget.tabType == TabType.TOPIC
                            ? '话题'
                            : '数码';
                        final currentTitle = count == 0
                            ? null
                            : (widget.tabType == TabType.TOPIC
                                ? data![0]
                                    .entities![_homeTopicController
                                        .currentIndex.value
                                        .clamp(0, count - 1)]
                                    .title
                                    .toString()
                                : data![_homeTopicController
                                        .currentIndex.value
                                        .clamp(0, count - 1)]
                                    .title
                                    .toString());
                        return Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: section,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (currentTitle != null)
                                TextSpan(
                                  text: ' · $currentTitle',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    // Fixed rail: the left list never scrolls, only the
                    // right pane does. Two independently scrolling panes
                    // felt fragmented; one fixed nav rail plus one
                    // scrolling content pane reads as a single screen.
                    // Rows keep their natural height when they fit; on a
                    // short screen (or with large text) they share the
                    // available height instead of overflowing.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final count = widget.tabType == TabType.TOPIC
                            ? data![0].entities!.length
                            : data!.length;
                        Widget railItem(int index) => IntrinsicHeight(
                              child: Obx(
                                () => InkWell(
                                  onTap: () {
                                    _homeTopicController.currentIndex.value =
                                        index;
                                    _controller.jumpToPage(index);
                                  },
                                  child: Ink(
                                    color: index ==
                                            _homeTopicController
                                                .currentIndex.value
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface
                                        : Colors.transparent,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          height: double.infinity,
                                          width: 3,
                                          color: index ==
                                                  _homeTopicController
                                                      .currentIndex.value
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.transparent,
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Container(
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            child: Text(
                                              widget.tabType == TabType.TOPIC
                                                  ? data![0]
                                                      .entities![index]
                                                      .title
                                                      .toString()
                                                  : data![index]
                                                      .title
                                                      .toString(),
                                              style: TextStyle(
                                                color: index ==
                                                        _homeTopicController
                                                            .currentIndex
                                                            .value
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                        final items =
                            List<Widget>.generate(count, railItem);
                        if (items.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        const estimatedRowHeight = 44.0;
                        if (count * estimatedRowHeight <=
                            constraints.maxHeight) {
                          return Column(children: items);
                        }
                        return Column(
                          children: [
                            for (final item in items) Expanded(child: item),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 78,
              child: Container(
                color: Theme.of(context).colorScheme.onInverseSurface,
                child: PageView.builder(
                  controller: _controller,
                  scrollDirection: Axis.vertical,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.tabType == TabType.TOPIC
                      ? data![0].entities!.length
                      : data!.length,
                  itemBuilder: (context, index) => TopicCategoryGrid(
                    url: widget.tabType == TabType.TOPIC
                        ? data![0].entities![index].url
                        : data![index].url,
                    title: widget.tabType == TabType.TOPIC
                        ? data![0].entities![index].title
                        : data![index].title,
                    gridEntityType:
                        widget.tabType == TabType.TOPIC ? 'topic' : 'product',
                  ),
                ),
              ),
            )
          ],
        );
      },
      onEmpty: GestureDetector(
        onTap: _homeTopicController.onReload,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10.0),
          child: const Text('暂无内容'),
        ),
      ),
      onError: (error) => GestureDetector(
        onTap: _homeTopicController.onReload,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10.0),
          child: Text(error ?? '加载失败，请重试'),
        ),
      ),
    );
  }
}
