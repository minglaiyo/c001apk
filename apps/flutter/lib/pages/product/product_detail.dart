/// Product detail parsing for the real product page.
///
/// The detail comes from `GET /v6/product/detail?id=...`, the same
/// endpoint coolapk-desktop uses. Tabs come from the detail's own
/// `tabList`, parsed the same way the desktop client's `productTabs`
/// does: only `/product/feedList` tabs for this product, with
/// `is_open` honoured and duplicates dropped. The `main` (config) and
/// `rating` tabs are not expanded into list tabs because their content
/// is already shown in the header (spec chips and the score card);
/// external tabs are skipped. Feed tabs are driven by
/// `NetworkRepo.getProductFeeds`, not guessed.
class ProductRatingItem {
  const ProductRatingItem({required this.name, required this.score});

  final String name;
  final double score;
}

class ProductTab {
  const ProductTab({
    required this.key,
    required this.label,
    required this.feedType,
    this.subId,
    this.listType,
  });

  final String key;
  final String label;

  /// Feed list type for `getProductFeeds`; empty for a sub-tab feed.
  final String feedType;
  final String? subId;
  final String? listType;
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.title,
    required this.logo,
    required this.description,
    this.hotNumText,
    this.commentNumText,
    this.followNumText,
    required this.score,
    required this.scoreCount,
    required this.specs,
    required this.ratingItems,
    required this.tabs,
  });

  final String id;
  final String title;
  final String logo;
  final String description;
  final String? hotNumText;
  final String? commentNumText;
  final String? followNumText;

  /// Owner average score when present, otherwise the overall average.
  final double score;
  final int scoreCount;
  final List<String> specs;
  final List<ProductRatingItem> ratingItems;
  final List<ProductTab> tabs;
}

String _text(dynamic value) {
  if (value is String) return value.trim();
  if (value == null) return '';
  return value.toString().trim();
}

String _firstText(Map map, List<String> keys) {
  for (final key in keys) {
    final text = _text(map[key]);
    if (text.isNotEmpty) return text;
  }
  return '';
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value)) ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}

bool _isOpen(dynamic value) {
  if (value == null) return true;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = _text(value);
  return text.isNotEmpty && text != '0';
}

/// Parses the `tabList` of a product detail into feed tabs, mirroring
/// coolapk-desktop's `productTabs`. Returns an empty list when the
/// detail carries no usable feed tabs; the page then shows only the
/// header instead of inventing a tab.
List<ProductTab> parseProductTabs(String productId, dynamic tabList) {
  if (tabList is! List) return [];
  final tabs = <ProductTab>[];
  final seen = <String>{};
  for (final item in tabList) {
    if (item is! Map) continue;
    if (!_isOpen(item['is_open'])) continue;
    final label = _firstText(item, ['title']);
    final rawUrl = _firstText(item, ['url']);
    if (label.isEmpty || rawUrl.isEmpty) continue;
    Uri? outer;
    try {
      outer = Uri.parse(rawUrl);
    } catch (_) {
      continue;
    }
    // A tab URL is either `/page?url=<inner>` or the inner URL itself.
    final innerRaw = outer.path == '/page'
        ? (outer.queryParameters['url'] ?? '')
        : rawUrl;
    Uri? inner;
    try {
      inner = Uri.parse(innerRaw);
    } catch (_) {
      continue;
    }
    // Tab URLs are not always URL-encoded: in an unencoded
    // `/page?url=/product/feedList&id=...&type=...` the `&` splits
    // id/type onto the outer query, leaving the inner URL with only
    // its path, so reading only the inner query rejects every tab.
    // Fall back to the outer query for keys the inner URL does not
    // carry; an encoded inner URL keeps precedence.
    final query = <String, String>{
      ...outer.queryParameters,
      ...inner.queryParameters,
    };
    if (inner.path != '/product/feedList') continue;
    if ((query['id'] ?? '') != productId) continue;
    final feedType = query['type'] ?? '';
    if (feedType == 'main' || feedType == 'rating') continue;
    String? subId;
    String key;
    if (feedType == 'subTabFeed') {
      subId = query['subId'] ?? '';
      if (!RegExp(r'^\d+$').hasMatch(subId)) continue;
      key = 'subtab:$subId';
    } else if (feedType.isNotEmpty) {
      key = feedType;
    } else {
      continue;
    }
    if (!seen.add(key)) continue;
    tabs.add(ProductTab(
      key: key,
      label: label,
      feedType: feedType == 'subTabFeed' ? '' : feedType,
      subId: subId,
      listType: query['listType'],
    ));
  }
  return tabs;
}

ProductDetail parseProductDetail(String productId, dynamic data) {
  if (data is! Map) {
    throw const FormatException('产品详情格式异常');
  }
  final ratingItems = <ProductRatingItem>[];
  final rawRatingItems = data['rating_item_info'];
  if (rawRatingItems is List) {
    for (final item in rawRatingItems) {
      if (item is! Map) continue;
      final name = _firstText(item, ['name', 'title']);
      if (name.isEmpty) continue;
      ratingItems.add(
          ProductRatingItem(name: name, score: _toDouble(item['score'])));
    }
  }
  final specs = <String>[];
  final rawSpecs = data['product_specs'];
  if (rawSpecs is List) {
    for (final spec in rawSpecs) {
      final text = _text(spec);
      if (text.isNotEmpty) specs.add(text);
    }
  }
  final score = _toDouble(data['owner_star_average_score'] ??
      data['rating_average_score']);
  final scoreCount = _toInt(data['owner_rating_total_num'] ??
      data['rating_total_num'] ??
      data['owner_star_total_count'] ??
      data['star_total_count']);
  return ProductDetail(
    id: productId,
    title: _firstText(
        data, ['title', 'index_title', 'alias_title', 'name']),
    logo: _firstText(data, ['logo', 'product_logo', 'pic', 'icon']),
    description:
        _firstText(data, ['description', 'device_info', 'subTitle']),
    hotNumText: _firstText(data, ['hot_num_txt']).isNotEmpty
        ? _firstText(data, ['hot_num_txt'])
        : (_text(data['hot_num']).isNotEmpty
            ? _text(data['hot_num'])
            : null),
    commentNumText: _firstText(data, ['feed_comment_num_txt']).isNotEmpty
        ? _firstText(data, ['feed_comment_num_txt'])
        : (_text(data['feed_comment_num']).isNotEmpty
            ? _text(data['feed_comment_num'])
            : null),
    followNumText: _firstText(data, ['follow_num_txt']).isNotEmpty
        ? _firstText(data, ['follow_num_txt'])
        : (_text(data['follow_num']).isNotEmpty
            ? _text(data['follow_num'])
            : null),
    score: score,
    scoreCount: scoreCount,
    specs: specs,
    ratingItems: ratingItems,
    tabs: parseProductTabs(productId, data['tabList']),
  );
}
