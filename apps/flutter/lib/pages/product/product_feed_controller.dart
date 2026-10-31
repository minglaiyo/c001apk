import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/common/common_controller.dart';
import '../../pages/product/product_detail.dart';

class ProductFeedController extends CommonController {
  ProductFeedController({
    required this.productId,
    required this.tab,
  });

  final String productId;
  final ProductTab tab;

  @override
  Future<LoadingState> customGetData() {
    return NetworkRepo.getProductFeeds(
      productId: productId,
      feedType: tab.feedType,
      subId: tab.subId,
      listType: tab.listType,
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
