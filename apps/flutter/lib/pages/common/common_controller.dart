import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData;

import '../../logic/model/feed/datum.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/home/return_top_controller.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import 'content_filter_list_mixin.dart';
import 'feed_write_actions_mixin.dart';

/// 通用分页列表引擎：游标翻页、重试循环与“整批被过滤”续载。
///
/// 内容过滤见 [ContentFilterListMixin]，删除/点赞/关注等写操作见
/// [FeedWriteActionsMixin]；两者以 mixin 组合，子类 API 保持不变。
abstract class CommonController extends GetxController
    with ContentFilterListMixin, FeedWriteActionsMixin {
  int page = 1;
  String? firstItem;
  String? lastItem;
  bool isLoading = false;
  bool isEnd = false;
  bool automaticLoadPaused = false;

  @override
  Rx<LoadingState> loadingState = LoadingState.loading().obs;
  Rx<LoadingState> footerState = LoadingState.empty().obs;
  GlobalKey<RefreshIndicatorState>? refreshKey;
  ScrollController? scrollController;
  ReturnTopController? returnTopController;

  @override
  void onInit() {
    super.onInit();
    initContentFiltering();
  }

  @override
  void onClose() {
    disposeContentFiltering();
    super.onClose();
  }

  List<Datum>? handleResponse(List<Datum> dataList) {
    return null;
  }

  LoadingState? handleExtraResponse() {
    return null;
  }

  Future<LoadingState> customGetData();

  Future<void> onGetData([bool isRefresh = true]) async {
    if (!isLoading) {
      initContentFiltering();
      final generation = GlobalData().sessionGeneration;
      isLoading = true;
      automaticLoadPaused = false;
      try {
        for (var attempt = 0; attempt < 3; attempt++) {
          LoadingState response = await customGetData();
          if (isClosed || generation != GlobalData().sessionGeneration) {
            isLoading = false;
            return;
          }
          if (response is Success) {
            List<Datum> dataList = supportsContentFilter
                ? response.rawResponse ?? response.response
                : response.response;
            firstItem ??=
                response.firstItem ?? dataList.firstOrNull?.id.toString();
            lastItem = response.lastItem ??
                dataList.lastOrNull?.id.toString() ??
                lastItem;
            List<Datum>? responseList = handleResponse(dataList);
            if (responseList != null) {
              dataList = responseList;
            }
            if (dataList.any((e) => e.entityTemplate == 'noMoreDataCard')) {
              isEnd = true;
              footerState.value = LoadingState.empty();
            }
            final hasVisibleItems =
                dataList.any((item) => filterMatch(item) == null);
            publishItems(dataList, append: !isRefresh || attempt > 0);
            if (loadingState.value is! Success) {
              loadingState.value = LoadingState.success(<Datum>[]);
            }
            page++;
            if (hasVisibleItems || isEnd) break;
            if (attempt == 2) {
              automaticLoadPaused = true;
              footerState.value = LoadingState.error('本批内容已过滤，点击继续加载');
            }
          } else {
            isEnd = response is Empty;
            automaticLoadPaused = response is Error;
            LoadingState? extraResponse = handleExtraResponse();
            if (extraResponse != null) {
              response = extraResponse;
            }
            if (isRefresh && attempt == 0) {
              if (response is Empty) {
                rawItems = [];
                filteredItems.clear();
              }
              loadingState.value = response;
              if (response is Success) {
                publishItems(List<Datum>.from(response.response));
              }
            } else {
              footerState.value = response;
            }
            break;
          }
        }
      } finally {
        isLoading = false;
      }
    }
  }

  void onReset() {
    page = 1;
    isEnd = false;
    automaticLoadPaused = false;
    firstItem = null;
    lastItem = null;
    footerState.value = LoadingState.loading();
    revealedContentKeys.clear();
  }

  void setFooterState(LoadingState footerState) {
    this.footerState.value = footerState;
  }

  void setLoadingState(LoadingState loadingState) {
    this.loadingState.value = loadingState;
  }

  Future<void> animateToTop() async {
    scrollController?.animToTop();
    returnTopController?.setIndex(999);
    refreshKey?.currentState?.show();
  }

  void onBlock(dynamic uid) {
    reapplyFilters();
  }
}
