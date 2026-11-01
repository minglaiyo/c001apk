import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../components/expressive_refresh_indicator.dart';
import '../../../components/network_image.dart';
import '../../../logic/model/feed/datum.dart';
import '../../../logic/state/loading_state.dart';
import '../../../utils/extensions.dart';
import '../../../utils/utils.dart';
import '../../carousel/carousel_page.dart';
import 'topic_grid_controller.dart';

/// Items of [items] that render as grid cells: topic entries on the 话题
/// tab, product entries on the 数码 tab. Banners, feeds and other card
/// types from the same category payload are left out of the grid.
List<Datum> topicGridItems(List<Datum> items, String entityType) {
  return items.where((item) => item.entityType == entityType).toList();
}

/// One grid cell: icon on top, name in the middle, hot count at the
/// bottom, matching the official topic-square grid. The tap target is the
/// same link the topic/product row cards open.
class TopicGridCell extends StatelessWidget {
  const TopicGridCell({
    super.key,
    required this.data,
    required this.onTap,
  });

  final Datum data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hotNum = data.hotNumTxt?.toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            clipNetworkImage(
              data.logo.orEmpty,
              radius: 16,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 8),
            Text(
              data.title.orEmpty,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            if (hotNum != null && hotNum.isNotEmpty) ...[
              // Pin the count to the cell bottom: names run 1-2 lines,
              // so without this the count sat at a different height in
              // every cell and the rows looked ragged. The tile height
              // is fixed (140), so the Spacer always has room.
              const Spacer(),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.whatshot,
                    size: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    hotNum,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The right pane of one left-rail category: a vertically scrollable
/// three-column grid of its topic/product entries.
///
/// When the category payload holds no topic/product entries at all, the
/// previous card-list presentation is kept instead of showing an empty
/// grid, so no category loses its content to this redesign.
class TopicCategoryGrid extends StatefulWidget {
  const TopicCategoryGrid({
    super.key,
    required this.url,
    required this.title,
    required this.gridEntityType,
  });

  final String? url;
  final String? title;
  final String gridEntityType;

  @override
  State<TopicCategoryGrid> createState() => _TopicCategoryGridState();
}

class _TopicCategoryGridState extends State<TopicCategoryGrid> {
  late final ScrollController _scrollController;

  String get _tag => (widget.url ?? '') + (widget.title ?? '');

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!Get.isRegistered<TopicGridController>(tag: _tag)) {
      return;
    }
    final controller = Get.find<TopicGridController>(tag: _tag);
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !controller.isEnd &&
        !controller.isLoading) {
      unawaited(controller.onGetData(false));
    }
  }

  Future<void> _reload(TopicGridController controller) async {
    controller.onReset();
    await controller.onGetData();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TopicGridController>(
      tag: _tag,
      init: TopicGridController(
        url: widget.url ?? '',
        title: widget.title ?? '',
      ),
      builder: (controller) => Obx(() {
        final state = controller.loadingState.value;
        if (state is Success) {
          final visible = state.response as List<Datum>;
          final gridItems = topicGridItems(visible, widget.gridEntityType);
          if (gridItems.isEmpty && visible.isNotEmpty) {
            // The page's mask band already carries the top inset, so
            // the fallback list must not add it a second time: zero
            // the top padding here (the bottom is untouched, and the
            // refresh capsule then sits at the content top, below
            // the mask, as on the grid path).
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(top: 0),
              ),
              child: CarouselPage(
                isInit: false,
                url: widget.url,
                title: widget.title,
                isHomeCard: true,
              ),
            );
          }
          // Same refresh indicator as every other list page
          // (common_body.dart): the bare Material RefreshIndicator
          // showed the default circular arrow, unlike the app's
          // expressive capsule spinner.
          return ExpressiveRefreshIndicator(
            onRefresh: () => _reload(controller),
            child: GridView.builder(
              controller: _scrollController,
              // The 12px grid gap on the sides; the top inset now
              // comes from the page's mask band above, so it is not
              // repeated here. The bottom adds the floating bottom
              // pill's clearance (the 96 the back-to-top button uses),
              // so the last row is not hidden behind the bottom bar.
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: 12 +
                    MediaQuery.paddingOf(context).bottom +
                    96,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                mainAxisExtent: 140,
              ),
              itemCount: gridItems.length,
              itemBuilder: (context, index) {
                final item = gridItems[index];
                return TopicGridCell(
                  data: item,
                  onTap: () => Utils.onOpenLink(
                    item.url.orEmpty,
                    item.title,
                    true,
                    context,
                  ),
                );
              },
            ),
          );
        }
        if (state is Error) {
          return GestureDetector(
            onTap: () {
              unawaited(_reload(controller));
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: Text(state.errMsg),
            ),
          );
        }
        if (state is Empty) {
          return GestureDetector(
            onTap: () {
              unawaited(_reload(controller));
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: const Text('暂无内容'),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      }),
    );
  }
}
