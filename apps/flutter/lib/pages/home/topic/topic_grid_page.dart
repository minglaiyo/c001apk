import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../components/expressive_refresh_indicator.dart';
import '../../../components/network_image.dart';
import '../../../components/status_views.dart';
import '../../../logic/model/feed/datum.dart';
import '../../../logic/state/loading_state.dart';
import '../../../utils/extensions.dart';
import '../../../router/link_resolver.dart';
import '../../product/rating_chart.dart' show parseHotCount;
import '../../carousel/carousel_page.dart';
import 'topic_grid_controller.dart';
import 'package:c001apk_flutter/constants/app_sizes.dart';
import '../../../constants/app_motion.dart';

/// Items of [items] that render as grid cells: topic entries on the 话题
/// tab, product entries on the 数码 tab. Banners, feeds and other card
/// types from the same category payload are left out of the grid.
List<Datum> topicGridItems(List<Datum> items, String entityType) {
  return items.where((item) => item.entityType == entityType).toList();
}

/// One grid cell: a rounded inverse-surface card — icon on top, name in
/// the middle (2 lines), hot count as a small pill pinned to the bottom.
/// The tap target is the same link the topic/product row cards open.
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
    final colors = Theme.of(context).colorScheme;
    final hotNum = data.hotNumTxt?.toString();
    final hasHot = hotNum != null && hotNum.isNotEmpty;
    return Material(
      color: colors.onInverseSurface,
      borderRadius: AppRadius.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              clipNetworkImage(
                data.logo.orEmpty,
                radius: 12,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 8),
              Text(
                data.title.orEmpty,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
              if (hasHot) ...[
                // Pin the count pill to the cell bottom: names run 1-2
                // lines, so without this the count sat at a different
                // height in every cell and the rows looked ragged.
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.whatshot,
                        size: 11,
                        color: colors.outline,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        hotNum,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1,
                          color: colors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
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

  /// 客户端热度排序开关。B 层参考级：不发明服务端排序参数；
  /// 热度取 Datum.hotNumTxt 文本解析（万/亿兜底），都没有时置灰。
  bool _hotSort = false;

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
          final hasHot = gridItems.any((item) =>
              parseHotCount(item.hotNumTxt) != null ||
              parseHotCount(item.commentNum) != null);
          final displayItems = _hotSort && hasHot
              ? (List<Datum>.from(gridItems)
                ..sort((a, b) => (parseHotCount(b.hotNumTxt) ??
                        parseHotCount(b.commentNum) ??
                        0)
                    .compareTo(parseHotCount(a.hotNumTxt) ??
                        parseHotCount(a.commentNum) ??
                        0)))
              : gridItems;
          return ExpressiveRefreshIndicator(
            onRefresh: () => _reload(controller),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Row(
                    children: [
                      _SortToggle(
                        hotSort: _hotSort,
                        hasHot: hasHot,
                        onChanged: (value) =>
                            setState(() => _hotSort = value),
                      ),
                      if (!hasHot) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '服务端未返回热度，热度排序不可用',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
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
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 148,
              ),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return _StaggerIn(
                  index: index,
                  child: TopicGridCell(
                    data: item,
                    onTap: () => openLink(
                      item.url.orEmpty,
                      item.title,
                      true,
                      context,
                    ),
                  ),
                );
              },
                ),
                ),
              ],
            ),
          );
        }
        if (state is Error) {
          return ErrorStatusView(
            message: state.errMsg,
            onTap: () {
              unawaited(_reload(controller));
            },
          );
        }
        if (state is Empty) {
          return EmptyStatusView(
            text: '暂无内容',
            onTap: () {
              unawaited(_reload(controller));
            },
          );
        }
        return const LoadingStatusView();
      }),
    );
  }
}

/// 默认/热度排序的分段控件：反向底（onInverseSurface）圆轨道 + 滑块，
/// 滑块用 AnimatedAlign 在两段之间平滑滑动，取代原先两个裸 ChoiceChip。
class _SortToggle extends StatelessWidget {
  const _SortToggle({
    required this.hotSort,
    required this.hasHot,
    required this.onChanged,
  });

  final bool hotSort;
  final bool hasHot;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.onInverseSurface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppDurations.control,
            curve: AppCurves.ease,
            alignment: hotSort ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 64,
              height: 28,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segment(
                context,
                '默认',
                selected: !hotSort,
                enabled: true,
                onTap: () => onChanged(false),
              ),
              _segment(
                context,
                '热度',
                selected: hotSort,
                enabled: hasHot,
                onTap: hasHot ? () => onChanged(true) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label, {
    required bool selected,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedDefaultTextStyle(
        duration: AppDurations.control,
        curve: AppCurves.ease,
        style: TextStyle(
          fontSize: 13,
          height: 1,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: !enabled
              ? colors.outline.withValues(alpha: 0.55)
              : selected
                  ? colors.onSurface
                  : colors.onSurfaceVariant,
        ),
        child: Container(
          width: 64,
          height: 28,
          alignment: Alignment.center,
          child: Text(label),
        ),
      ),
    );
  }
}

/// 格子入场：淡入 + 轻微上移，按列位置错开延迟（封顶 8 档），
/// 滚动/切换分类/切换排序时给网格一点「活」的感觉。控制器一次性的，
/// forward 完成后即为静态，不额外占渲染成本。
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.control,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppCurves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: 36 * widget.index.clamp(0, 8)),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
