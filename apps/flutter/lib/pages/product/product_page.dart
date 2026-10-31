import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../logic/network/network_repo.dart';
import '../../pages/product/product_detail.dart';
import '../../pages/product/product_feed_content.dart';
import '../../pages/product/product_feed_controller.dart';
import '../../utils/extensions.dart';

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

  /// Whether the product header (stats, score, rating bars, specs)
  /// is expanded. Collapsed, only the logo + title row remains, so
  /// the header stops eating a quarter of the page and the feed list
  /// gets the space. The tab bar is always visible either way.
  ///
  /// The header is fully shown only when the page first opens: once
  /// the feed list scrolls down past a threshold it collapses on its
  /// own, and scrolling back to the top does not re-expand it. The
  /// title-row button still expands it manually on demand.
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
    });
  }

  Widget _buildHeader(ProductDetail detail) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.logo.isNotEmpty)
                ClipRRect(
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
              if (detail.logo.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title.isNotEmpty ? detail.title : '数码产品',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_headerExpanded &&
                        detail.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
                  ],
                ),
              ),
              IconButton(
                tooltip: _headerExpanded ? '收起' : '展开',
                icon: Icon(_headerExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down),
                onPressed: () {
                  setState(() {
                    _headerExpanded = !_headerExpanded;
                  });
                },
              ),
            ],
          ),
          if (_headerExpanded) ...[
            const SizedBox(height: 12),
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
              ],
            ),
          ],
          if (_headerExpanded && detail.score > 0) ...[
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
          if (_headerExpanded && detail.specs.isNotEmpty) ...[
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
            appBar: AppBar(title: const Text('数码产品')),
            body: SingleChildScrollView(child: _buildHeader(detail)),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('数码产品'),
            actions: [_buildSortMenu(detail)],
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
