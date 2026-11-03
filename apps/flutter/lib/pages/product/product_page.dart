import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData;

import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/product/product_detail.dart';
import '../../pages/product/rating_chart.dart';
import '../../pages/product/product_feed_content.dart';
import '../../pages/product/product_feed_controller.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../components/imageview.dart';

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

  @override
  void initState() {
    super.initState();
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

  /// Opens the product gallery in the existing image viewer.
  /// B 层参考级：先试 GET /v6/product/mediaList（未实测参考，来自
  /// daimiaopeng/coolapk-desktop 公开代码），拿到多图就进多图图集；
  /// 失败或为空时回落到单图 logo 图集。详情解析本身不改。
  Future<void> _openProductGallery(ProductDetail detail) async {
    if (detail.logo.isEmpty) return;
    var urls = <String>[detail.logo];
    try {
      final result = await NetworkRepo.getProductMediaList(id: detail.id);
      if (result is Success<List<String>> && result.response.isNotEmpty) {
        urls = result.response;
      }
    } catch (_) {
      // 回落到单图，不提示、不崩。
    }
    if (!mounted) return;
    Get.toNamed('/imageview', arguments: mediaGalleryArguments(urls));
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
              const SizedBox(height: 12),
              const Text('总体星级分布（参考接口，未实测）'),
              const SizedBox(height: 8),
              FutureBuilder<LoadingState<Map<String, dynamic>>>(
                future: NetworkRepo.getProductRatingChart(detail.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final state = snapshot.data!;
                  if (state is! Success<Map<String, dynamic>>) {
                    return const Text(
                        '总体分布暂未返回（参考未实测，待真机样本）。');
                  }
                  final chart = parseRatingChart(state.response);
                  if (!chart.recognized) {
                    return const Text(
                        '总体分布暂未返回（参考未实测，待真机样本）。');
                  }
                  final total = chart.total ?? 1;
                  return Column(
                    children: [
                      for (var star = 5; star >= 1; star--)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              SizedBox(width: 32, child: Text('$star 星')),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: ((chart.starCounts[star] ?? 0) /
                                          total)
                                      .clamp(0.0, 1.0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${chart.starCounts[star] ?? 0} 人'),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                '分项数值均为平均分；上方的星级分布为总体分布，分项人数服务端可能根本没有，不硬编。',
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
          if (hasLogo || hasDescription)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLogo)
                  GestureDetector(
                    onTap: () => _openProductGallery(detail),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                      detail.logo,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                        width: 64,
                        height: 64,
                      ),
                      ),
                    ),
                  ),
                if (hasLogo && hasDescription) const SizedBox(width: 12),
                if (hasDescription)
                  Expanded(
                    child: Text(
                      detail.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          if (hasLogo || hasDescription) const SizedBox(height: 12),
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
          if (detail.score > 0) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showRatingDetail(detail),
              borderRadius: BorderRadius.circular(8),
              child: Row(
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
            ),
            if (detail.ratingItems.isNotEmpty) ...[
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
            ],
          ],
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


  /// The ⋮ sort menu in the AppBar, mirroring the topic discussion
  /// sort menu (默认 / 最新发布 / 热门). Picking a sort reloads every
  /// tab controller that already exists; tabs built afterwards read
  /// the shared selection on their first load.
  Widget _buildSortMenu(ProductDetail detail) {
    return Obx(() {
      final current = _sortController.sortType.value;
      return PopupMenuButton<int>(
        tooltip: '排序',
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          _sortController.sortType.value = value;
          for (final tab in detail.tabs) {
            final tag = '${detail.id}${tab.key}';
            if (Get.isRegistered<ProductFeedController>(tag: tag)) {
              final controller = Get.find<ProductFeedController>(tag: tag);
              controller.onReset();
              controller.onGetData();
            }
          }
        },
        itemBuilder: (context) => [
          for (final entry in {
            0: '默认',
            1: '最新发布',
            2: '热门',
          }.entries)
            PopupMenuItem<int>(
              value: entry.key,
              child: Row(
                children: [
                  Expanded(child: Text(entry.value)),
                  if (entry.key == current) const Icon(Icons.check),
                ],
              ),
            ),
        ],
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
              _buildSortMenu(detail),
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
