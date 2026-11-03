import 'package:get/get.dart';

import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/common/common_controller.dart';
import '../../pages/product/product_detail.dart';

/// Sort state shared by all tabs of one product page, mirroring the
/// topic discussion sort menu (默认 / 最新发布 / 热门). It lives on the
/// product page (tag = product id) so every tab's feed controller
/// reads the same selection, including tabs that are built only after
/// the user picks a sort.
class ProductFeedSortController extends GetxController {
  /// 0 = 默认, 1 = 最新发布, 2 = 热门.
  final sortType = 0.obs;

  String get label => switch (sortType.value) {
        1 => '最新发布',
        2 => '热门',
        _ => '默认',
      };
}

class ProductFeedController extends CommonController {
  ProductFeedController({
    required this.productId,
    required this.tab,
  });

  final String productId;
  final ProductTab tab;

  /// Effective `listType` for this load: the shared sort selection
  /// overrides the tab's own listType, exactly like the product
  /// discussion sort in `discussion_sort_url.dart` (默认 keeps the
  /// tab's listType, 最新 uses `dateline_desc`, 热门 uses
  /// `rank_score`). Tabs that have not been built yet pick the
  /// selection up on their first load.
  String? get _effectiveListType {
    if (!Get.isRegistered<ProductFeedSortController>(tag: productId)) {
      return tab.listType;
    }
    return switch (
        Get.find<ProductFeedSortController>(tag: productId).sortType.value) {
      1 => 'dateline_desc',
      2 => 'rank_score',
      _ => tab.listType,
    };
  }

  @override
  Future<LoadingState> customGetData() {
    return NetworkRepo.getProductFeeds(
      productId: productId,
      feedType: tab.feedType,
      subId: tab.subId,
      listType: _effectiveListType,
      page: page,
      firstItem: firstItem,
      lastItem: lastItem,
    );
  }

  @override
  void onInit() {
    super.onInit();
    onGetData();
  }
}
