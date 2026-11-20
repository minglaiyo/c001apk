import 'dart:async';
import 'dart:io';

import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/logic/state/loading_state.dart';
import 'package:c001apk_flutter/pages/user/user_controller.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _ParallelUser extends UserController {
  _ParallelUser({required super.uid});

  final profile = Completer<LoadingState>();
  int feedCalls = 0;

  @override
  Future<LoadingState> fetchUserData() => profile.future;

  @override
  Future<LoadingState> customGetData() async {
    feedCalls++;
    return Success([Datum(entityType: 'feed', uid: 1007278, id: 1)]);
  }
}

/// 主页动态与资料请求并行（不再串行等待资料回包才发起列表），
/// 本地屏蔽用户仍然以屏蔽提示覆盖列表状态。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('user-parallel-');
    Hive.init(temp.path);
    GStorage.settings = await Hive.openBox('settings');
    GStorage.blackList = await Hive.openBox('blackList');
  });
  setUp(() async {
    await GStorage.blackList
        .put(BlackListBoxKey.userBlackList, <String>[]);
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('feed request starts before the profile response arrives', () async {
    final controller = _ParallelUser(uid: '1007278');
    final done = controller.onGetUserData();
    // 让并行请求的同步启动段先跑完。
    await Future<void>.delayed(Duration.zero);
    expect(controller.feedCalls, 1,
        reason: '动态列表应在资料回包之前就已发起');

    controller.profile.complete(Success(
        Datum(entityType: 'user', uid: 1007278, username: '测试用户')));
    await done;
    expect(controller.userState.value, isA<Success>());
    expect(controller.username, '测试用户');
    expect(controller.loadingState.value, isA<Success>());
    final items =
        (controller.loadingState.value as Success).response as List<Datum>;
    expect(items, hasLength(1));
  });

  test('profile failure no longer leaves the feed tab loading forever',
      () async {
    final controller = _ParallelUser(uid: '1007278');
    final done = controller.onGetUserData();
    await Future<void>.delayed(Duration.zero);
    expect(controller.feedCalls, 1);

    controller.profile.complete(LoadingState.error('资料加载失败'));
    await done;
    expect(controller.userState.value, isA<Error>());
    // 动态列表照常返回并展示（旧实现会永远停在 loading）。
    expect(controller.loadingState.value, isA<Success>());
  });

  test('a locally blocked user skips the feed request entirely', () async {
    await GStorage.blackList
        .put(BlackListBoxKey.userBlackList, <String>['1007278']);
    final controller = _ParallelUser(uid: '1007278');
    final done = controller.onGetUserData();
    await Future<void>.delayed(Duration.zero);
    expect(controller.feedCalls, 0, reason: '屏蔽判定可先行短路，不发列表请求');

    controller.profile.complete(Success(
        Datum(entityType: 'user', uid: 1007278, username: '被屏蔽的人')));
    await done;
    expect(controller.userState.value, isA<Success>());
    final state = controller.loadingState.value;
    expect(state, isA<Error>());
    expect((state as Error).errMsg, contains('已屏蔽用户'));
  });
}
