import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/item_card.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  String _typeOf(Datum item) {
    final type = item.entityType.orEmpty;
    if (type.isNotEmpty) return type;
    final feedType = item.feedType.orEmpty;
    if (feedType.isNotEmpty) return feedType;
    return '未知';
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
        _error = (result as Error).errMsg;
      } else {
        if (reset) _all.clear();
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
                        ? const Center(child: Text('暂无内容'))
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
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                // 混合类型（动态/话题/用户等）用通用卡片，
                                // 而不是只按动态卡片渲染。
                                child: itemCard(filtered[index]),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
