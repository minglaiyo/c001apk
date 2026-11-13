import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart' hide Response, FormData;

import '../../logic/model/feed/datum.dart';
import '../../logic/model/feed/user_action.dart';
import '../../logic/model/login/login_response.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../utils/extensions.dart';

/// 列表控制器上的写操作：删除、点赞、关注、私信已读。
///
/// 从 CommonController 拆出。经由抽象成员触达宿主的列表状态，
/// 不直接依赖 CommonController 类型；子类可覆写 [handleLike]
/// 与 [handleGetFollow] 做界面联动。
mixin FeedWriteActionsMixin on GetxController {
  Rx<LoadingState> get loadingState;

  /// 已发布的原始条目（删除后重发布用）。
  List<Datum> get rawItems;

  /// 重新发布列表（删除/取消关注后刷新视图）。
  void publishItems(List<Datum> items, {bool append = false});

  /// 点赞后由宿主自行维护计数展示时返回 true。
  bool handleLike(dynamic like, dynamic likenum) => false;

  /// 关注状态变化后的宿主联动（如刷新关注按钮）。
  void handleGetFollow() {}

  Future<void> postLikeDeleteFollow(
    dynamic id,
    dynamic fid, {
    bool isFollow = false,
    bool isFeed = false,
    bool isReply = false,
    bool isNoti = false,
    bool isProduct = false,
  }) async {
    String url = isFeed
        ? '/v6/feed/deleteFeed'
        : isReply
            ? '/v6/feed/deleteReply'
            : isNoti
                ? '/v6/notification/delete'
                : '/v6/product/changeFollowStatus';
    try {
      Response response = await NetworkRepo.postLikeDeleteFollow(
        url,
        id: isProduct ? null : id,
        data: isProduct
            ? FormData.fromMap({'id': id, 'status': isFollow ? 0 : 1})
            : null,
      );
      readApiObject(response);
      LoginResponse data = LoginResponse.fromJson(response.data);
      if (!data.message.isNullOrEmpty) {
        SmartDialog.showToast(data.message!);
        if (isProduct) {
          handleGetFollow();
        }
      } else if (data.data != null) {
        List<Datum> dataList = rawItems;
        if (fid != null) {
          dataList = dataList.map((data) {
            if (data.id == fid) {
              return data
                ..replyRows =
                    data.replyRows!.where((data) => data.id != id).toList();
            } else {
              return data;
            }
          }).toList();
        } else {
          dataList = dataList.where((data) => data.id != id).toList();
        }
        publishItems(dataList);
        SmartDialog.showToast(data.data!);
      }
    } catch (e) {
      SmartDialog.showToast(ApiFailure.fromError(e).message);
    }
  }

  Future<void> onLike(
    dynamic id,
    dynamic like, {
    bool isFeed = false,
    bool isReply = false,
  }) async {
    try {
      String isLike = isFeed
          ? (like == 1 ? 'unlike' : 'like')
          : (like == 1 ? 'unLikeReply' : 'likeReply');
      Response response =
          await NetworkRepo.postLikeDeleteFollow('/v6/feed/$isLike', id: id);
      readApiObject(response);
      LoginResponse datum = LoginResponse.fromJson(response.data);
      if (!datum.message.isNullOrEmpty) {
        SmartDialog.showToast(datum.message!);
      } else {
        if (isFeed && handleLike(like, datum.data['count'])) {
          return;
        }
        List<Datum> dataList = (loadingState.value as Success).response;
        dataList = dataList.map((data) {
          if (data.id == id) {
            return data
              ..likenum = isFeed ? datum.data['count'] : datum.data
              ..userAction = UserAction(like: like == 1 ? 0 : 1);
          } else {
            return data;
          }
        }).toList();
        loadingState.value = LoadingState.success(dataList);
      }
    } catch (e) {
      SmartDialog.showToast(ApiFailure.fromError(e).message);
    }
  }

  Future<void> onGetFollow(
    bool isFollow,
    String url, {
    dynamic tag,
    dynamic id,
  }) async {
    try {
      Response response = await NetworkRepo.getFollow(url, tag: tag, id: id);
      final body =
          readApiObject(response, allowSuccessWithoutData: tag != null);
      LoginResponse data = LoginResponse.fromJson(body);
      if (!data.message.isNullOrEmpty) {
        SmartDialog.showToast(data.message!);
        if (tag != null) {
          handleGetFollow();
        }
      } else if (data.data != null) {
        SmartDialog.showToast(isFollow ? '取消关注成功' : '关注成功');
        handleGetFollow();
      }
    } catch (e) {
      SmartDialog.showToast(ApiFailure.fromError(e).message);
    }
  }

  void onPM(dynamic id) {
    List<Datum> dataList = (loadingState.value as Success).response;
    dataList = dataList.map((data) {
      if (data.id == id) {
        return data..unreadNum = null;
      } else {
        return data;
      }
    }).toList();
    loadingState.value = LoadingState.success(dataList);
  }
}
