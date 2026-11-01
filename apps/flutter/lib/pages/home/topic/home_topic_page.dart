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
        // A rail-coloured mask band behind the floating top bar: it
        // spans the full width at the scaffold's top inset height, so
        // it appears with the bar and collapses to the status strip
        // when the bar hides (the inset itself is animated by the
        // scaffold). It lives only in this page, so only the 话题 and
        // 数码 tabs get it. The grid's and rail's own top padding no
        // longer carry the inset – the mask does that job – which also
        // removes the split-colour gap the inset used to leave.
        // Scrollable rail, one roomy row per category on both tabs
        // (15px text, vertical padding 10, the same row height on
        // 话题 and 数码). The rail was fixed for a while, but with 24
        // 话题 categories against 14 数码 ones the fixed rail squeezed
        // 话题 rows far below 数码's roomy rows, so the user chose
        // scrolling back. Only the rail scrolls; the right grid keeps
        // its own scroll, and the mask band above still carries the
        // top inset, so the list itself needs no top padding.
        Widget railItem(int index) =>
            IntrinsicHeight(
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
                            padding: EdgeInsets.symmetric(
                                vertical:
                                    10),
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
        final count = widget.tabType == TabType.TOPIC
            ? data![0].entities!.length
            : data!.length;
        return Column(
          children: [
            Container(
              height: MediaQuery.paddingOf(context).top,
              color: Theme.of(context).colorScheme.surface,
            ),
            Expanded(
              child: Row(
          children: [
            Expanded(
              flex: 22,
              child: Padding(
                // The rail scrolls, so it never picks up the
                // scaffold's top inset on its own; the mask band
                // above already offsets the content, so the rail only
                // needs the bottom clearance for the floating bottom
                // pill (same 96 the back-to-top button uses).
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 96,
                ),
                child: count == 0
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: count,
                        itemBuilder: (context, index) => railItem(index),
                      ),
              ),
            ),
            Expanded(
              flex: 78,
              child: Container(
                // Same surface as the rail and the mask band: the right
                // pane used to paint onInverseSurface here, which left a
                // hard vertical seam against the white rail and made the
                // selected rail row (also onInverseSurface) look like it
                // bled into the grid. With one shared background the seam
                // is gone and the selected row reads as a highlight.
                color: Theme.of(context).colorScheme.surface,
                child: PageView.builder(
                  controller: _controller,
                  scrollDirection: Axis.vertical,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.tabType == TabType.TOPIC
                      ? data[0].entities!.length
                      : data.length,
                  itemBuilder: (context, index) => TopicCategoryGrid(
                    url: widget.tabType == TabType.TOPIC
                        ? data[0].entities![index].url
                        : data[index].url,
                    title: widget.tabType == TabType.TOPIC
                        ? data[0].entities![index].title
                        : data[index].title,
                    gridEntityType:
                        widget.tabType == TabType.TOPIC ? 'topic' : 'product',
                  ),
                ),
              ),
            )
          ],
              ),
            ),
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
