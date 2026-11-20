import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart' hide Response;

import '../../logic/model/feed/datum.dart';
import '../../logic/model/login/login_response.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/common/common_controller.dart';
import '../../utils/extensions.dart';
import '../../utils/storage_util.dart';
import '../../utils/global_data.dart';
import '../../logic/local_follow/local_follow_store.dart';
import '../../logic/network/api_failure.dart';

class UserController extends CommonController {
  UserController({
    required this.uid,
  });

  late String uid;
  String? username;

  RxDouble scrollRatio = 0.0.obs;

  bool isBlocked = false;

  @override
  void revealAuthorForPage(String uid) {
    super.revealAuthorForPage(uid);
    if (uid == this.uid &&
        userState.value is Success &&
        loadingState.value is Error &&
        !isLoading) {
      onReset();
      onGetData();
    }
  }

  @override
  void reapplyFilters() {
    final previouslyBlocked = isBlocked;
    isBlocked = GStorage.checkUser(uid);
    if (isBlocked && !revealedAuthorUids.contains(uid)) {
      setBlockedLoaidngState();
      return;
    }
    if (previouslyBlocked && !isBlocked && loadingState.value is Error) {
      onReset();
      onGetData();
      return;
    }
    super.reapplyFilters();
  }

  @override
  List<Datum>? handleResponse(List<Datum> dataList) {
    if (dataList.lastOrNull?.entityTemplate == 'noMoreDataCard') {
      isEnd = true;
      footerState.value = LoadingState.empty();
    }
    return super.handleResponse(dataList);
  }

  @override
  Future<LoadingState> customGetData() {
    return NetworkRepo.getUserFeed(
      uid: uid,
      page: page,
      firstItem: firstItem,
      lastItem: lastItem,
    );
  }

  Rx<LoadingState> userState = LoadingState.loading().obs;

  void setUserState(LoadingState userState) {
    this.userState.value = userState;
  }

  /// 资料请求单独抽出，便于测试注入。
  Future<LoadingState> fetchUserData() =>
      NetworkRepo.getDataFromUrl(url: '/v6/user/space?uid=$uid');

  Future<void> onGetUserData() async {
    // 动态列表与资料请求并行：/u/:uid 传入的就是数字 uid，与资料回包一致，
    // 无需等资料回包再发起列表请求，首屏少等一个来回。屏蔽判定读的是本机
    // 名单，不依赖资料内容，可先行短路：已屏蔽用户直接不发列表请求。
    // （此前 uid 会用资料回包重写一次；路由保证进来就是数字 uid，二者恒等，
    // 不再中途改写以免列表分页与已发请求不一致。）
    final locallyBlocked =
        GStorage.checkUser(uid) && !revealedAuthorUids.contains(uid);
    final feedFuture = locallyBlocked ? null : onGetData();
    final LoadingState response = await fetchUserData();
    if (response is Success) {
      username = (response.response as Datum).username;
    }
    isBlocked = GStorage.checkUser(uid);
    if (isBlocked && !revealedAuthorUids.contains(uid)) {
      if (feedFuture != null) await feedFuture;
      if (!isClosed) setBlockedLoaidngState();
    }
    userState.value = response;
  }

  @override
  void onBlock(uid) {
    super.onBlock(uid);
    isBlocked = true;
    setBlockedLoaidngState();
  }

  void setBlockedLoaidngState() {
    loadingState.value = LoadingState.error('已屏蔽用户 $username');
  }

  @override
  void onInit() {
    super.onInit();
    onGetUserData();
  }

  bool _followBusy = false;

  Future<void> onLocalFollow() async {
    if (_followBusy || userState.value is! Success) return;
    if (GlobalData().isLogin && !LocalFollowStore().secretEnabled) return;
    _followBusy = true;
    try {
      final store = LocalFollowStore();
      final data = (userState.value as Success).response as Datum;
      final following = store.contains(uid);
      if (following) {
        await store.unfollow(uid);
      } else {
        await store.follow(uid, data.username ?? '', data.userAvatar ?? '');
      }
      final label = GlobalData().isLogin ? '悄悄关注' : '本地关注';
      SmartDialog.showToast(
          following ? '已取消$label，仅修改本机名单' : '已$label，仅保存在本机，不会同步到账号');
    } catch (_) {
      SmartDialog.showToast('本地关注保存失败，请重试');
    } finally {
      _followBusy = false;
    }
  }

  Future<void> onFollow(dynamic uid, dynamic isFollow) async {
    if (!GlobalData().isLogin) return onLocalFollow();
    if (_followBusy) return;
    _followBusy = true;
    try {
      String url = isFollow == 1 ? '/v6/user/unfollow' : '/v6/user/follow';
      Response response = await NetworkRepo.postLikeDeleteFollow(url, uid: uid);
      LoginResponse datum = LoginResponse.fromJson(readApiObject(response));
      if (!datum.message.isNullOrEmpty) {
        SmartDialog.showToast(datum.message!);
      } else if (datum.data != null) {
        Datum data = (userState.value as Success).response;
        userState.value = LoadingState.success(data..isFollow = datum.data);
        SmartDialog.showToast(isFollow == 1 ? '取消关注成功' : '关注成功');
      }
    } catch (e) {
      SmartDialog.showToast(ApiFailure.fromError(e).message);
    } finally {
      _followBusy = false;
    }
  }
}
