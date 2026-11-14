import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/cards/feed_card.dart';
import '../../components/adaptive_card_list.dart';
import '../../components/confirm_dialog.dart';
import '../../components/status_views.dart';
import '../../pages/history/history_controller.dart';

// ignore: constant_identifier_names
enum HistoryType {
  // ignore: constant_identifier_names
  Favorite,
  // ignore: constant_identifier_names
  History;

  String get label => this == HistoryType.Favorite ? '本地收藏' : '浏览历史';
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryType _type = Get.arguments['type'];

  /// '全部' shows every record. '未知' covers records written before the
  /// type field existed (their feedTypeName is null); their category is
  /// never invented after the fact.

  late final _controller = Get.put(
    HistoryController(type: _type),
    tag: _type.name,
  );

  String _selectedFilter = '全部';

  @override
  void dispose() {
    Get.delete<HistoryController>(
      tag: _type.name,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: Text(_type.label),
          actions: [
                  // 云端历史入口（B 层参考级，与本地线分开，不合并）。
                  IconButton(
                    onPressed: () => Get.toNamed('/cloud_history'),
                    icon: const Icon(Icons.cloud_outlined),
                    tooltip: '云端历史',
                  ),
                  if (_controller.dataList.isNotEmpty)
                  IconButton(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context: context,
                        title: '确定清除全部${_type == HistoryType.Favorite ? '收藏' : '浏览历史'}？',
                        confirmLabel: '确定',
                        cancelLabel: '取消',
                      );
                      if (confirmed) _controller.clearAll();
                    },
                    icon: const Icon(Icons.clear_all),
                    tooltip: '清除全部',
                  ),
                ],
          bottom: const PreferredSize(
              preferredSize: Size.zero, child: Divider(height: 1)),
        ),
        body: Builder(
          builder: (context) {
            final allItems = _controller.dataList;
            if (allItems.isEmpty) {
              return const EmptyStatusView();
            }
            final types = <String>{
              for (final item in allItems)
                if ((item.feedTypeName ?? '').isNotEmpty) item.feedTypeName!,
            };
            final filters = [
              '全部',
              ...types,
              if (allItems.any((item) => (item.feedTypeName ?? '').isEmpty))
                '未知',
            ];
            final effectiveFilter =
                filters.contains(_selectedFilter) ? _selectedFilter : '全部';
            final filtered = effectiveFilter == '全部'
                ? allItems
                : effectiveFilter == '未知'
                    ? allItems
                        .where(
                            (item) => (item.feedTypeName ?? '').isEmpty)
                        .toList()
                    : allItems
                        .where((item) => item.feedTypeName == effectiveFilter)
                        .toList();
            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      for (final filter in filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _selectedFilter == filter,
                            onSelected: (_) =>
                                setState(() => _selectedFilter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: AdaptiveCardList(
                    padding: EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 10,
                      bottom: 10 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) => FeedCard(
                      isHistory: true,
                      data: filtered[index],
                      onDelete: (id) {
                        _controller.onDeleteFeed(filtered[index].id);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
