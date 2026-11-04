import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData;

import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../pages/product/product_comparison_controller.dart';
import '../../pages/product/product_config.dart';
import '../../pages/product/product_config_ui.dart';
import '../../pages/product/product_detail.dart';
import '../../pages/product/product_feed_content.dart';
import '../../pages/product/product_feed_controller.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';

/// The real product page. The route used to point at [TopicPage] as a
/// placeholder, so opening a product from search results showed a topic
/// page instead of the product.
class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late final String _id = Get.parameters['id'].orEmpty;
  Future<ProductDetail>? _detailFuture;

  /// Local follow override: the detail's `followed` is the server
  /// state at load; tapping the button flips this optimistically and
  /// reverts it if the toggle call fails.
  bool? _followedOverride;

  /// Guards the follow toggle against double taps while a call is
  /// in flight.
  bool _followBusy = false;

  /// Whether the product header (logo, description, stats, score,
  /// rating bars, specs) is expanded. The product name lives in the
  /// AppBar title, and there is no expand icon: tapping the AppBar
  /// title toggles this flag.
  ///
  /// The header is fully shown only when the page first opens: once
  /// the feed list scrolls down past a threshold it collapses on its
  /// own, hiding the whole header including the score, and scrolling
  /// back to the top does not re-expand it. Tapping the AppBar title
  /// expands it manually on demand. The tab bar is always visible
  /// either way.
  bool _headerExpanded = true;

  /// Auto-collapses the header when the feed list scrolls down.
  /// Scroll notifications bubble up from the inner tab lists, so this
  /// works no matter which tab is visible, without tracking each
  /// tab's scroll controller. Returns false so the notification keeps
  /// bubbling to the refresh indicator and other listeners.
  bool _onScrollNotification(ScrollNotification notification) {
    if (!_headerExpanded) return false;
    if (notification is ScrollUpdateNotification &&
        notification.metrics.axis == Axis.vertical &&
        (notification.scrollDelta ?? 0) > 0 &&
        notification.metrics.pixels > 120) {
      setState(() {
        _headerExpanded = false;
      });
    }
    return false;
  }

  /// Tapping the AppBar product name expands or collapses the header.
  void _toggleHeader() {
    setState(() {
      _headerExpanded = !_headerExpanded;
    });
  }

  late final ProductFeedSortController _sortController;

  /// Process-wide comparison selection (see
  /// `ProductComparisonController`): shared across product pages and
  /// never deleted with this page.
  late final ProductComparisonController _comparison;

  @override
  void initState() {
    super.initState();
    _comparison = ProductComparisonController.instance;
    _sortController = Get.isRegistered<ProductFeedSortController>(tag: _id)
        ? Get.find<ProductFeedSortController>(tag: _id)
        : Get.put(ProductFeedSortController(), tag: _id);
    _detailFuture = NetworkRepo.getProductDetail(_id);
  }

  @override
  void dispose() {
    Get.delete<ProductFeedSortController>(tag: _id);
    super.dispose();
  }

  void _retry() {
    setState(() {
      _detailFuture = NetworkRepo.getProductDetail(_id);
      _followedOverride = null;
    });
  }

  /// Toggles following this product. Mirrors the topic follow flow
  /// and the Compose product follow: the server call is
  /// POST /v6/product/changeFollowStatus with inverted status
  /// (currently followed -> 0 cancels, otherwise 1). The button flips
  /// optimistically and reverts on failure; when not logged in it
  /// prompts a login instead of firing the call. The follow ack is
  /// message-only (status + message, no data key), so the envelope
  /// check must allow success without data: otherwise every
  /// successful tap reverts with a missing-data error.
  Future<void> _toggleFollow(ProductDetail detail) async {
    if (_followBusy) return;
    if (!GlobalData().isLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先登录'),
          action: SnackBarAction(
            label: '登录',
            onPressed: () => Get.toNamed('/login'),
          ),
        ),
      );
      return;
    }
    final was = _followedOverride ?? detail.followed ?? false;
    setState(() {
      _followedOverride = !was;
      _followBusy = true;
    });
    try {
      final response = await NetworkRepo.postLikeDeleteFollow(
        '/v6/product/changeFollowStatus',
        data: FormData.fromMap({'id': detail.id, 'status': was ? 0 : 1}),
      );
      readApiObject(response, allowSuccessWithoutData: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _followedOverride = was;
        });
      } else {
        _followedOverride = was;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiFailure.fromError(e).message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _followBusy = false;
        });
      } else {
        _followBusy = false;
      }
    }
  }

  void _showComparisonSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Opens the config list dialog for this product. The dialog's
  /// "参数" action closes the list and opens the details dialog;
  /// its "对比" action toggles the process-wide selection with the
  /// same toasts as Costben's `toggleProductConfig`.
  void _openConfigList(ProductDetail detail) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ProductConfigListDialog(
        productTitle: detail.title,
        configs: detail.configs,
        comparison: _comparison,
        onViewConfig: (config) {
          Navigator.of(dialogContext).pop();
          _showConfigDetails(config);
        },
        onToggleCompare: (config) {
          final result = _comparison.toggle(
            ProductComparisonSelection(
              productTitle: detail.title,
              productLogo: detail.logo.isNotEmpty ? detail.logo : null,
              config: config,
            ),
          );
          switch (result) {
            case ProductComparisonToggleResult.added:
              _showComparisonSnack('已加入对比');
            case ProductComparisonToggleResult.removed:
              _showComparisonSnack('已移出对比');
            case ProductComparisonToggleResult.limitReached:
              _showComparisonSnack(
                '最多选择 ${ProductComparisonController.maxSelections} 个配置',
              );
            case ProductComparisonToggleResult.invalid:
              _showComparisonSnack('该配置暂不支持对比');
          }
        },
        onOpenComparison: () {
          Navigator.of(dialogContext).pop();
          _openComparison();
        },
      ),
    );
  }

  void _showConfigDetails(ProductConfig config) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => ProductConfigDetailsDialog(config: config),
    );
  }

  /// Opens the comparison dialog, with Costben's entry guards:
  /// 0 selections and 1 selection only toast, 2+ load in parallel
  /// inside the dialog.
  void _openComparison() {
    final selections = _comparison.selections.toList();
    if (selections.isEmpty) {
      _showComparisonSnack('请先选择要对比的配置');
      return;
    }
    if (selections.length < 2) {
      _showComparisonSnack('再选择一个配置即可对比');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => ProductComparisonDialog(
        selections: selections,
        comparison: _comparison,
      ),
    );
  }

  /// Second row under the product header, mirroring Costben's
  /// `TopicHeader` buttons: "参数（N）" only when this product's
  /// detail carries `configRows`, "对比（M）" when configs exist or
  /// the process-wide selection is non-empty (M = selection count).
  /// When neither applies, no row and no spacing is left behind.
  /// The row is reactive: toggling a config on any product page
  /// updates the comparison count here.
  Widget _buildConfigButtons(ProductDetail detail) {
    return Obx(() {
      final hasConfigs = detail.configs.isNotEmpty;
      final comparisonCount = _comparison.selections.length;
      final buttons = <Widget>[];
      if (hasConfigs) {
        buttons.add(
          Expanded(
            child: OutlinedButton(
              onPressed: () => _openConfigList(detail),
              child: Text('参数（${detail.configs.length}）'),
            ),
          ),
        );
      }
      if (hasConfigs || comparisonCount > 0) {
        if (buttons.isNotEmpty) {
          buttons.add(const SizedBox(width: 10));
        }
        buttons.add(
          Expanded(
            child: OutlinedButton(
              onPressed: _openComparison,
              child: Text('对比（$comparisonCount）'),
            ),
          ),
        );
      }
      if (buttons.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          const SizedBox(height: 12),
          Row(children: buttons),
        ],
      );
    });
  }

  /// Shows the already-parsed rating detail: total score, rater count,
  /// and per-aspect average scores. Averages only: no headcount
  /// distribution is parsed or shown here.
  void _showRatingDetail(ProductDetail detail) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title.isNotEmpty ? detail.title : '数码产品',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    detail.score.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    detail.scoreCount > 0
                        ? '酷安评分 · ${detail.scoreCount} 人'
                        : '酷安评分',
                  ),
                ],
              ),
              if (detail.ratingItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('分项平均分'),
                const SizedBox(height: 8),
                for (final item in detail.ratingItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 72, child: Text(item.name)),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (item.score / 10).clamp(0.0, 1.0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(item.score.toStringAsFixed(1)),
                      ],
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 12),
                const Text('暂无分项评分'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ProductDetail detail) {
    // Collapsed, the whole header hides, score included, so scrolling
    // down leaves only the AppBar (with the product name) and the tab
    // bar. The caller wraps this in an AnimatedSize, so collapsing
    // and re-expanding animate instead of jumping.
    if (!_headerExpanded) return const SizedBox.shrink();
    final hasLogo = detail.logo.isNotEmpty;
    final hasDescription = detail.description.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image + rating side by side: the product picture on the
          // left, the rating block (total + per-aspect averages) in
          // the remaining width on the right. The picture is static:
          // the gallery is closed by user decision, so tapping it
          // does nothing and fires no request. This whole row lives
          // inside _buildHeader, which the caller hides entirely on
          // scroll and restores via the AppBar title tap, so picture
          // and rating collapse/restore together.
          if (hasLogo || detail.score > 0)
            // Deterministic row height (regression fix for the #58
            // stretch-only row, which left the image with no height
            // and the rating column as a flex child, so row height,
            // image height and rating height waited on each other
            // inside AnimatedSize and the body could come out blank
            // in release builds): IntrinsicHeight sizes the row once
            // from the tallest child's intrinsic height (the rating
            // block, total + per-aspect bars), and the image then
            // fills that full height via SizedBox(height: infinity)
            // under the row's stretch constraint, so no blank block
            // is left under the image. BoxFit.cover crops the image
            // to fill without distortion. Width 120 keeps it
            // proportionate without squeezing the rating bars.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasLogo)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 120,
                        height: double.infinity,
                        child: Image.network(
                          detail.logo,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 120,
                            height: double.infinity,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                        ),
                      ),
                    ),
                if (hasLogo) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detail.score > 0) ...[
                        InkWell(
                          onTap: () => _showRatingDetail(detail),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              Text(
                                detail.score.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                detail.scoreCount > 0
                                    ? '酷安评分 · ${detail.scoreCount} 人'
                                    : '酷安评分',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (detail.ratingItems.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final item in detail.ratingItems)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 64,
                                      child: Text(item.name,
                                          style: const TextStyle(fontSize: 12))),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: (item.score / 10).clamp(0.0, 1.0),
                                      minHeight: 3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(item.score.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ] else if (hasDescription)
                        Text(
                          detail.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasLogo || hasDescription || detail.score > 0)
            const SizedBox(height: 12),
          if (hasDescription && detail.score > 0)
            Text(
              detail.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (hasDescription && detail.score > 0) const SizedBox(height: 12),
          Row(
            children: [
              if (detail.hotNumText != null)
                Text('${detail.hotNumText} 热度'),
              if (detail.hotNumText != null &&
                  detail.commentNumText != null)
                const Text(' · '),
              if (detail.commentNumText != null)
                Text('${detail.commentNumText} 讨论'),
              if (detail.commentNumText != null &&
                  detail.followNumText != null)
                const Text(' · '),
              if (detail.followNumText != null)
                Text('${detail.followNumText} 关注'),
              const Spacer(),
              OutlinedButton(
                onPressed:
                    _followBusy ? null : () => _toggleFollow(detail),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  (_followedOverride ?? detail.followed ?? false)
                      ? '已关注'
                      : '关注',
                ),
              ),
            ],
          ),
          _buildConfigButtons(detail),
          if (detail.specs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detail.specs
                  .map((spec) => Chip(label: Text(spec)))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// The AppBar title: the product name itself, tappable to expand
  /// or collapse the header. Falls back to 数码产品 when the product
  /// has no title.
  Widget _buildTitle(ProductDetail detail) {
    return Tooltip(
      message: _headerExpanded ? '收起' : '展开',
      child: GestureDetector(
        onTap: _toggleHeader,
        child: Text(detail.title.isNotEmpty ? detail.title : '数码产品'),
      ),
    );
  }


  /// Applies a sort selection: same semantics as the old AppBar ⋮
  /// sort menu (0 = 默认 keeps the tab's listType, 1 = 最新 uses
  /// `dateline_desc`, 2 = 热门 uses `rank_score`; see
  /// `ProductFeedSortController`). Picking a sort reloads every tab
  /// controller that already exists; tabs built afterwards read the
  /// shared selection on their first load.
  void _applySort(ProductDetail detail, int value) {
    _sortController.sortType.value = value;
    for (final tab in detail.tabs) {
      final tag = '${detail.id}${tab.key}';
      if (Get.isRegistered<ProductFeedController>(tag: tag)) {
        final controller = Get.find<ProductFeedController>(tag: tag);
        controller.onReset();
        controller.onGetData();
      }
    }
  }

  /// Discussion sort as a grey pill segmented control, in the
  /// Yuxiximyxx `_buildSortSelector` shape (grey pill track, selected
  /// pill white with a light shadow; dark mode uses a translucent
  /// white track and a dark selected pill). It replaces the AppBar ⋮
  /// sort menu — the values and the reload behaviour above are
  /// unchanged, only the labels follow the reference pill
  /// (默认 / 最新 / 热度 instead of the menu's 最新发布 / 热门).
  /// Note the scope is the same as the old menu: the sort is shared
  /// across all tabs through `ProductFeedSortController`, so the pill
  /// is shown for the whole product page, not only for a discussion
  /// tab; narrowing it to one tab would change the sort semantics.
  Widget _buildSortPill(ProductDetail detail) {
    return Obx(() {
      final current = _sortController.sortType.value;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFF4F3F8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in {
              0: '默认',
              1: '最新',
              2: '热度',
            }.entries)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _applySort(detail, entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 5),
                  decoration: entry.key == current
                      ? BoxDecoration(
                          color: isDark
                              ? const Color(0xFF3A3A3C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: entry.key == current
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: entry.key == current
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductDetail>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('数码产品')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('数码产品')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error?.toString() ?? '产品详情加载失败'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _retry, child: const Text('重试')),
                ],
              ),
            ),
          );
        }
        final detail = snapshot.data!;
        if (detail.tabs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: _buildTitle(detail)),
            body: SingleChildScrollView(child: _buildHeader(detail)),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: _buildTitle(detail),
            actions: [
              IconButton(
                onPressed: () => Get.toNamed('/search', parameters: {
                  'title': detail.title,
                  'pageType': 'product_phone',
                  'pageParam': detail.id,
                }),
                icon: const Icon(Icons.search),
                tooltip: '搜索',
              ),
            ],
          ),
          body: DefaultTabController(
            length: detail.tabs.length,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    alignment: Alignment.topCenter,
                    child: _buildHeader(detail),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildSortPill(detail),
                    ),
                  ),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: detail.tabs
                        .map((tab) => Tab(text: tab.label))
                        .toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: detail.tabs
                          .map((tab) => ProductFeedContent(
                                productId: detail.id,
                                tab: tab,
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
