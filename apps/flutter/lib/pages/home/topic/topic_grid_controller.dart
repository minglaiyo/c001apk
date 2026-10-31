import '../../../logic/network/network_repo.dart';
import '../../../logic/state/loading_state.dart';
import '../../common/common_controller.dart';

/// Loads one left-rail category's items for the topic/product grid.
///
/// Same endpoint and pagination as [CarouselController]; only the
/// presentation differs: a grid of topic/product entries instead of the
/// card list. The caller filters the loaded items by entity type.
class TopicGridController extends CommonController {
  TopicGridController({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Future<LoadingState> customGetData() {
    return NetworkRepo.getDataList(
      url: url,
      title: title,
      subTitle: '',
      firstItem: firstItem,
      lastItem: lastItem,
      page: page,
    );
  }

  @override
  void onInit() {
    super.onInit();
    onGetData();
  }
}
