import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../logic/network/network_repo.dart';
import '../../pages/product/product_detail.dart';
import '../../pages/product/product_feed_content.dart';
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

  @override
  void initState() {
    super.initState();
    _detailFuture = NetworkRepo.getProductDetail(_id);
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
                    errorBuilder: (_, _, _) => const SizedBox(
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
                    if (detail.description.isNotEmpty) ...[
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
            ],
          ),
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
          if (detail.score > 0) ...[
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数码产品')),
      body: FutureBuilder<ProductDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error?.toString() ?? '产品详情加载失败'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _retry, child: const Text('重试')),
                ],
              ),
            );
          }
          final detail = snapshot.data!;
          if (detail.tabs.isEmpty) {
            return SingleChildScrollView(child: _buildHeader(detail));
          }
          return DefaultTabController(
            length: detail.tabs.length,
            child: Column(
              children: [
                _buildHeader(detail),
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
          );
        },
      ),
    );
  }
}
