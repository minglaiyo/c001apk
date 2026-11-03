import 'package:flutter/material.dart';

import '../../components/item_card.dart';
import '../../components/network_image.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../product/product_detail.dart';
import '../../utils/date_util.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/utils.dart';

/// 云端浏览历史页，B 层参考级。
///
/// 未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码：
/// GET /v6/user/hitHistoryList?type=…&page=…。注意：这不是
/// recentHistoryList，那是“我的常去”。type 取值未实测，先传空，
/// 客户端按 entityType / feedType 兜底筛；与本地 historyFeed
/// 不合并、不去重，页面文案写明是云端线。未登录时只提示登录。
/// Target identified from a history row's own fields, for detail
/// enrichment. The id here is always a target id (from targetRow.id or
/// from a /feed/<id> / /product/<id> url), never a history record id.
class _HistoryTarget {
  const _HistoryTarget(this.kind, this.id);
  final String kind;
  final String id;
}

class CloudHistoryPage extends StatefulWidget {
  const CloudHistoryPage({super.key});

  @override
  State<CloudHistoryPage> createState() => _CloudHistoryPageState();
}

class _CloudHistoryPageState extends State<CloudHistoryPage> {
  final _all = <Datum>[];
  String _filter = '全部';
  String? _firstItem;
  String? _lastItem;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _isEnd = false;
  bool _serverEmpty = false;
  String? _error;
  // Detail enrichment: full feed/product data fetched by target id,
  // keyed by the original history row. The list itself (_all) is never
  // replaced, so order and the '浏览记录' filter stay stable while
  // cards swap from info cards to full cards as details arrive.
  final _feedDetails = <String, Datum>{};
  final _productDetails = <String, ProductDetail>{};
  final _enrichAttempted = <String>{};
  int _enrichGeneration = 0;
  bool _enriching = false;
  bool _enrichPending = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  String _typeOf(Datum item) {
    final type = item.entityType.orEmpty;
    if (type == 'history') {
      // 纯 history 记录：服务端自己的 targetType 更能说明它指向什么，
      // 都没有时就叫“浏览记录”，不要把原始英文 entityType 当筛选名。
      final targetType = item.targetType.orEmpty;
      return targetType.isNotEmpty ? targetType : '浏览记录';
    }
    if (type.isNotEmpty) return type;
    final feedType = item.feedType.orEmpty;
    if (feedType.isNotEmpty) return feedType;
    return '未知';
  }

  /// itemCard 能渲染的类型（与 components/item_card.dart 的分支一致；
  /// 'card' 只有模板在已知列表里时才算能渲染，其余一律走记录卡片）。
  bool _isRenderable(Datum item) {
    final type = item.entityType.orEmpty;
    if (type == 'card') {
      return {
        'imageCarouselCard_1',
        'iconLinkGridCard',
        'iconMiniScrollCard',
        'iconMiniGridCard',
        'imageSquareScrollCard',
        'titleCard',
        'iconScrollCard',
        'imageTextScrollCard',
        'noMoreDataCard',
        'messageCard',
        'refreshCard',
      }.contains(item.entityTemplate.orEmpty);
    }
    return {
      'feed',
      'feed_reply',
      'apk',
      'product',
      'user',
      'topic',
      'contacts',
      'recentHistory',
      'notification',
      'message',
      'collection',
    }.contains(type);
  }

  /// 目标还原不了的历史记录本身：显示记录自带的标题/类型/时间，
  /// 有 url 时点按走通用链接打开；没有 url 时就是一张静态信息卡，
  /// 绝不再显示“暂不支持此内容”。
  Widget _historyRecordCard(Datum item) {
    String? firstNonEmpty(List<String?> values) {
      for (final value in values) {
        if (value != null && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final title = firstNonEmpty([
          item.title,
          item.messageTitle,
          item.message,
          item.description,
        ]) ??
        '浏览记录';
    String timeText = '';
    try {
      if (item.dateline != null) timeText = DateUtil.fromToday(item.dateline);
    } catch (_) {
      timeText = '';
    }
    // Show every field the row actually carries (username, device,
    // target type, time), deduplicated; nothing is invented here.
    final metaParts = <String>[];
    for (final part in [
      item.username,
      item.deviceTitle,
      item.targetTypeTitle,
      item.targetType,
      timeText,
    ]) {
      final trimmed = part?.trim() ?? '';
      if (trimmed.isNotEmpty && !metaParts.contains(trimmed)) {
        metaParts.add(trimmed);
      }
    }
    final meta = metaParts.isEmpty ? null : metaParts.join(' · ');
    // Body text when the row carries one distinct from the title
    // (title is often just "<user>的动态" or a product name).
    final bodyText = firstNonEmpty([
      item.message,
      item.messageTitle,
    ]);
    // Directly null-checked local: the #57 analyzer flagged bodyText!
    // at 149 as unnecessary_non_null_assertion, and a bare ! here is
    // exactly the class of warning that fails the build under
    // --fatal-warnings. This form needs no assertion at all.
    final displayBody =
        bodyText != null && bodyText != title ? bodyText : null;
    final url = item.url.orEmpty;
    final body = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (displayBody != null) ...[
            const SizedBox(height: 4),
            Text(displayBody,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
          ],
          if (meta != null) ...[
            const SizedBox(height: 4),
            Text(meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ],
      ),
    );
    return Material(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      color: Theme.of(context).colorScheme.onInverseSurface,
      child: url.isEmpty
          ? body
          : InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              onTap: () => Utils.onOpenLink(url, title, true, context),
              child: body,
            ),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (!GlobalData().isLogin) {
      setState(() {
        _loading = false;
        _error = '请先登录';
      });
      return;
    }
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _serverEmpty = false;
        _page = 1;
        _firstItem = null;
        _lastItem = null;
        _isEnd = false;
        _feedDetails.clear();
        _productDetails.clear();
        _enrichAttempted.clear();
        _enrichGeneration++;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    final result = await NetworkRepo.getHitHistoryList(
      page: _page,
      firstItem: _firstItem,
      lastItem: _lastItem,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (result is Success) {
        _serverEmpty = false;
        final items = result.response as List<Datum>;
        if (reset) {
          _all.clear();
        }
        _all.addAll(items);
        _firstItem = result.firstItem ?? _firstItem;
        _lastItem = result.lastItem ?? _lastItem;
        _page++;
        if (items.isEmpty) _isEnd = true;
      } else if (result is Error) {
        _error = result.errMsg;
      } else {
        // Empty：服务端确实返回了空（不再是旧实现里“被白名单过滤丢光”
        // 也显示的同一个“暂无内容”），页面要把这点写清楚。
        if (reset) _all.clear();
        _serverEmpty = true;
        _isEnd = true;
      }
    });
    if (result is Success) {
      // Fire-and-forget: info cards show immediately, full cards swap
      // in as their target details arrive.
      _enrichItems();
    }
  }

  String _rowKey(Datum item) =>
      '${item.id}|${item.url.orEmpty}|${item.dateline}';

  _HistoryTarget? _targetFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments;
    for (var i = 0; i + 1 < segments.length; i++) {
      if ((segments[i] == 'feed' || segments[i] == 'product') &&
          RegExp(r'^[0-9]+$').hasMatch(segments[i + 1])) {
        return _HistoryTarget(segments[i], segments[i + 1]);
      }
    }
    return null;
  }

  _HistoryTarget? _targetOf(Datum item) {
    // 1. The server's own target object, when present.
    final targetRow = item.targetRow;
    if (targetRow != null) {
      final rowId = targetRow.id?.toString().trim() ?? '';
      final rowKind =
          (targetRow.entityType ?? targetRow.targetType ?? '').trim();
      if (rowId.isNotEmpty && (rowKind == 'feed' || rowKind == 'product')) {
        return _HistoryTarget(rowKind, rowId);
      }
      final fromUrl = _targetFromUrl(targetRow.url ?? '');
      if (fromUrl != null) return fromUrl;
    }
    // 2. The row's own url, e.g. /feed/<id> or /product/<id>.
    final fromUrl = _targetFromUrl(item.url.orEmpty);
    if (fromUrl != null) return fromUrl;
    // 3. Only for rows the parser already accepted as a feed/product
    // target (not for 'history' rows): there item.id IS the target id,
    // because it came from a nested target object. A 'history' row's
    // id is the history record id and is never used here.
    final entityKind = item.entityType;
    if ((entityKind == 'feed' || entityKind == 'product') &&
        item.id != null &&
        item.id.toString().trim().isNotEmpty) {
      final bodyEmpty = (item.message ?? '').trim().isEmpty &&
          (item.messageTitle ?? '').trim().isEmpty &&
          (item.picArr ?? []).isEmpty;
      if (entityKind == 'product' || bodyEmpty) {
        // The 'feed'/'product' check above does not promote entityKind:
        // Dart does not promote a nullable value through an ||
        // equality check, so narrow it explicitly here. This line is
        // only reached when entityKind is 'feed' or 'product', so the
        // ?? '' fallback is unreachable and changes no semantics.
        return _HistoryTarget(entityKind ?? '', item.id.toString());
      }
    }
    return null;
  }

  Future<void> _enrichItems() async {
    if (_enriching) {
      _enrichPending = true;
      return;
    }
    _enriching = true;
    final generation = _enrichGeneration;
    try {
      for (var i = 0; i < _all.length; i++) {
        if (!mounted || generation != _enrichGeneration) return;
        final item = _all[i];
        final key = _rowKey(item);
        if (_feedDetails.containsKey(key) ||
            _productDetails.containsKey(key) ||
            _enrichAttempted.contains(key)) {
          continue;
        }
        // Rows already fully rendered need no fetch, except product
        // rows (AppCard shows no rating) and blank feed rows (no body).
        final needsFetch = item.entityType == 'history' ||
            item.entityType == 'product' ||
            (item.entityType == 'feed' &&
                (item.message ?? '').trim().isEmpty &&
                (item.messageTitle ?? '').trim().isEmpty &&
                (item.picArr ?? []).isEmpty);
        if (!needsFetch) continue;
        final target = _targetOf(item);
        if (target == null) continue;
        _enrichAttempted.add(key);
        if (target.kind == 'feed') {
          final result = await NetworkRepo.getFeedDetail(id: target.id);
          if (!mounted || generation != _enrichGeneration) return;
          if (result is Success) {
            final detail = result.response;
            if (detail is Datum) {
              setState(() => _feedDetails[key] = detail);
            }
          }
          // On failure the info card stays; the attempted set stops
          // retry loops. Nothing is invented on failure.
        } else if (target.kind == 'product') {
          try {
            final detail = await NetworkRepo.getProductDetail(target.id);
            if (!mounted || generation != _enrichGeneration) return;
            setState(() => _productDetails[key] = detail);
          } catch (_) {
            // Keep the info card on failure.
          }
        }
      }
    } finally {
      _enriching = false;
      if (_enrichPending) {
        _enrichPending = false;
        _enrichItems();
      }
    }
  }

  Widget _productHistoryCard(ProductDetail detail, Datum row) {
    String timeText = '';
    try {
      if (row.dateline != null) timeText = DateUtil.fromToday(row.dateline);
    } catch (_) {
      timeText = '';
    }
    // Locals, not field assertions: final-field promotion through &&
    // is analyzer-version dependent, and a stray ! fails the build
    // under --fatal-warnings. Local null checks promote reliably.
    final hot = detail.hotNumText;
    final comments = detail.commentNumText;
    final follows = detail.followNumText;
    final stats = [
      if (hot != null && hot.isNotEmpty) '$hot 热度',
      if (comments != null && comments.isNotEmpty) '$comments 讨论',
      if (follows != null && follows.isNotEmpty) '$follows 关注',
      if (timeText.isNotEmpty) timeText,
    ].join(' · ');
    final url =
        row.url.orEmpty.isNotEmpty ? row.url.orEmpty : '/product/${detail.id}';
    return Material(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      color: Theme.of(context).colorScheme.onInverseSurface,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: () => Utils.onOpenLink(url, detail.title, true, context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              clipNetworkImage(detail.logo,
                  width: 56, height: 56, radius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (detail.score > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                          detail.scoreCount > 0
                              ? '${detail.score.toStringAsFixed(1)} 酷安评分 · ${detail.scoreCount} 人'
                              : '${detail.score.toStringAsFixed(1)} 酷安评分',
                          style: const TextStyle(fontSize: 14)),
                    ],
                    if (detail.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(detail.description,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                    ],
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(stats,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.outline)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = <String>{
      for (final item in _all) _typeOf(item),
    };
    final filters = ['全部', ...types];
    final effective = filters.contains(_filter) ? _filter : '全部';
    final filtered = effective == '全部'
        ? _all
        : _all.where((item) => _typeOf(item) == effective).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('云端历史')),
      body: Column(
        children: [
          if (_all.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  for (final filter in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) =>
                            setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _load(reset: true),
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Text(_serverEmpty
                                ? '服务端返回为空：云端暂无浏览记录，或接口未返回条目'
                                : '暂无内容'))
                        : ListView.builder(
                            padding: EdgeInsets.only(
                              left: 10,
                              right: 10,
                              top: 10,
                              bottom: 10 +
                                  MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: filtered.length + 1,
                            itemBuilder: (context, index) {
                              if (index == filtered.length) {
                                if (_isEnd) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: Text('没有更多了')),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: _loadingMore
                                        ? const CircularProgressIndicator()
                                        : TextButton(
                                            onPressed: () =>
                                                _load(reset: false),
                                            child: const Text('加载更多'),
                                          ),
                                  ),
                                );
                              }
                              final item = filtered[index];
                              final rowKey = _rowKey(item);
                              final enrichedFeed = _feedDetails[rowKey];
                              final enrichedProduct = _productDetails[rowKey];
                              // Enriched full cards first; otherwise the
                              // generic card for renderable rows, and the
                              // record card for history rows whose target
                              // could not be identified or fetched.
                              final Widget card;
                              if (enrichedFeed != null) {
                                card = itemCard(enrichedFeed);
                              } else if (enrichedProduct != null) {
                                card = _productHistoryCard(
                                    enrichedProduct, item);
                              } else if (_isRenderable(item)) {
                                card = itemCard(item);
                              } else {
                                card = _historyRecordCard(item);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: card,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
