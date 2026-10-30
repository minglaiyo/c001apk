import 'package:get/get.dart';

import '../../../logic/model/feed/datum.dart';
import '../../../logic/network/network_repo.dart';
import '../../../logic/state/loading_state.dart';
import '../../../pages/common/common_controller.dart';
import '../../../pages/home/home_page.dart' show TabType;

class HomeFeedController extends CommonController {
  HomeFeedController({
    required this.tabType,
    required this.installTime,
    this.url,
    this.title,
  });

  final TabType tabType;
  final String installTime;
  int firstLaunch = 1;
  String? url;
  String? title;

  /// Count for the floating "更新了 N 条动态" capsule, or null when the
  /// capsule is hidden. Set by [publishItems] after a refresh, cleared
  /// by [hideNewFeedTip] or by a tap-triggered refresh.
  final newFeedCount = Rxn<int>();

  /// List offset at the moment the capsule appeared. The page fades the
  /// capsule out as the user scrolls down from this offset.
  double newFeedTipShownOffset = 0;

  /// True while the current [onGetData] call is a refresh (not a
  /// load-more). Only a refresh may show the capsule.
  bool _tipRefreshInProgress = false;

  /// Set when the capsule itself was tapped to refresh: that refresh
  /// must not show the capsule again, or the tap-to-hide would be
  /// undone as soon as the refresh completes. Cleared in [onGetData]'s
  /// finally block, so a failed tap-refresh does not suppress a later
  /// legitimate refresh tip.
  bool _suppressNextTip = false;

  void hideNewFeedTip() {
    newFeedCount.value = null;
  }

  /// Called by the capsule's tap handler before it scrolls to top and
  /// reloads: hides the capsule and suppresses the tip for that one
  /// refresh. The caller still does the scroll and reload itself.
  void markTipTapRefresh() {
    _suppressNextTip = true;
    newFeedCount.value = null;
  }

  @override
  Future<void> onGetData([bool isRefresh = true]) async {
    _tipRefreshInProgress = isRefresh;
    try {
      await super.onGetData(isRefresh);
    } finally {
      _tipRefreshInProgress = false;
      _suppressNextTip = false;
    }
  }

  @override
  void publishItems(List<Datum> items, {bool append = false}) {
    // TiebaLite's rule, adapted: only a refresh of a non-empty list
    // shows the tip, never the first load, a load-more, or a local
    // republish (like/delete). The previous first item is the anchor:
    // items before it in the new list are the new items; if it is gone
    // entirely, the refreshed page size is used, exactly like
    // TiebaLite's RefreshSuccess(data.size).
    final hadItems = filteredItems.isNotEmpty;
    final previousFirstKey =
        hadItems ? _itemKey(filteredItems.first) : null;
    super.publishItems(items, append: append);
    if (append ||
        !_tipRefreshInProgress ||
        !hadItems ||
        previousFirstKey == null ||
        _suppressNextTip) {
      return;
    }
    final newItems = filteredItems;
    if (newItems.isEmpty) {
      newFeedCount.value = null;
      return;
    }
    final previousIndex =
        newItems.indexWhere((item) => _itemKey(item) == previousFirstKey);
    newFeedCount.value =
        previousIndex > 0 ? previousIndex : newItems.length;
    newFeedTipShownOffset = scrollController?.offset ?? 0;
  }

  /// The same identity key `CommonController.handleUnique` uses, so a
  /// refreshed item is recognised as the same item as before.
  String? _itemKey(Datum item) {
    final id = item.entityId ?? item.id;
    if (id == null) return null;
    return '${item.entityType}:$id';
  }

  @override
  Future<LoadingState> customGetData() {
    return tabType == TabType.FEED
        ? NetworkRepo.getHomeFeed(
            page: page,
            firstLaunch: firstLaunch,
            installTime: installTime,
            firstItem: firstItem,
            lastItem: lastItem,
          )
        : NetworkRepo.getDataList(
            url: url!,
            title: title!,
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
