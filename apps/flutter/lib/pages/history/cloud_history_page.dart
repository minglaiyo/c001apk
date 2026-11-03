import 'package:flutter/material.dart';

import '../../components/item_card.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
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
    final meta = firstNonEmpty([
      [
        item.targetTypeTitle,
        item.targetType,
        item.username,
        timeText,
      ].where((part) => part != null && part!.trim().isNotEmpty).join(' · '),
    ]);
    final url = item.url.orEmpty;
    final body = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '云端线（hitHistoryList），与本地浏览历史不合并、不去重；接口为未实测参考，首次打开即当探针。',
              style: TextStyle(fontSize: 12),
            ),
          ),
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
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                // 混合类型（动态/话题/用户等）用通用卡片，
                                // 而不是只按动态卡片渲染；目标还原不了的
                                // history 记录用记录卡片，绝不走 itemCard
                                // 的默认“暂不支持此内容”分支。
                                child: _isRenderable(item)
                                    ? itemCard(item)
                                    : _historyRecordCard(item),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
