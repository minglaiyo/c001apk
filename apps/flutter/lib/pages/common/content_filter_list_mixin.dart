import 'dart:async';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../logic/content_filter/app_content_filter.dart';
import '../../logic/content_filter/content_filter_projection.dart';
import '../../logic/content_filter/content_filter_rule.dart';
import '../../logic/content_filter/content_filter_service.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/state/loading_state.dart';
import '../../utils/extensions.dart';
import '../../utils/storage_util.dart';

/// 列表控制器的内容过滤与“临时展示”能力。
///
/// 从 CommonController 拆出：过滤服务监听、黑名单联动、
/// 匹配判定与已过滤/已展示集合的维护。宿主在 onInit/onClose
/// 分别调用 [initContentFiltering]/[disposeContentFiltering]。
mixin ContentFilterListMixin on GetxController {
  /// 关闭过滤的列表（如聊天）依靠它逃逸基类行为。
  bool get supportsContentFilter => true;

  List<Datum> rawItems = [];
  final filteredItems = <Datum>[].obs;
  final revealedContentKeys = <String>{};
  final revealedAuthorUids = <String>{};
  ContentFilterService? _filterService;
  StreamSubscription? _legacyFilterSubscription;

  void initContentFiltering() {
    if (!supportsContentFilter) return;
    if (_filterService != AppContentFilter.service) {
      _filterService?.removeListener(reapplyFilters);
      _filterService = AppContentFilter.service;
      _filterService?.addListener(reapplyFilters);
    }
    if (_legacyFilterSubscription == null && Hive.isBoxOpen('blackList')) {
      _legacyFilterSubscription =
          GStorage.blackList.watch().listen((_) => reapplyFilters());
    }
  }

  void disposeContentFiltering() {
    _filterService?.removeListener(reapplyFilters);
    _legacyFilterSubscription?.cancel();
  }

  FilterMatch? filterMatch(Datum item) {
    if (!supportsContentFilter) return null;
    if (revealedContentKeys.contains(ContentFilterProjection.keyOf(item))) {
      return null;
    }
    final match = ContentFilterProjection.match(item);
    if (match?.kind == FilterRuleKind.author &&
        revealedAuthorUids.contains('${item.uid}')) {
      return null;
    }
    return match;
  }

  void revealItem(Datum item) {
    revealedContentKeys.add(ContentFilterProjection.keyOf(item));
    reapplyFilters();
  }

  void revealAuthorForPage(String uid) {
    revealedAuthorUids.add(uid);
    reapplyFilters();
  }

  void publishItems(List<Datum> items, {bool append = false}) {
    initContentFiltering();
    final previous = switch (loadingState.value) {
      Success(:final response) when !supportsContentFilter =>
        List<Datum>.from(response),
      _ => rawItems,
    };
    final combined = append ? [...previous, ...items] : items;
    rawItems = handleUnique(combined) ?? combined;
    reapplyFilters();
  }

  void reapplyFilters() {
    if (isClosed) return;
    final hidden = <Datum>[];
    final visible = <Datum>[];
    for (final item in rawItems) {
      if (filterMatch(item) != null) {
        hidden.add(item);
        // Keep comment relationships; each comment card renders a placeholder.
        if (item.entityType == 'feed_reply') visible.add(item);
      } else {
        visible.add(item);
      }
    }
    filteredItems.assignAll(hidden);
    if (rawItems.isNotEmpty || loadingState.value is Success) {
      loadingState.value = LoadingState.success(visible);
    }
  }

  List<Datum>? handleUnique(List<Datum> dataList) {
    return dataList.unique((data) =>
        '${data.entityType}:${data.entityId ?? data.id ?? identityHashCode(data)}');
  }

  /// 宿主提供列表状态；过滤发布需要读写它。
  Rx<LoadingState> get loadingState;
}
