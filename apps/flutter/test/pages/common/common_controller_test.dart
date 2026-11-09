import 'package:c001apk_flutter/logic/network/network_repo.dart';
import 'package:c001apk_flutter/logic/state/loading_state.dart';
import 'package:c001apk_flutter/pages/common/common_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [CommonController] whose pages are scripted in advance, so the
/// pagination, failure and refresh mechanics of [CommonController.onGetData]
/// can be tested without a network layer or the content filter.
class ScriptedController extends CommonController {
  ScriptedController(this.scripted);

  final List<LoadingState> scripted;
  int calls = 0;

  @override
  bool get supportsContentFilter => false;

  @override
  Future<LoadingState> customGetData() async {
    final response =
        calls < scripted.length ? scripted[calls] : LoadingState.empty();
    calls++;
    return response;
  }
}

Map<String, dynamic> feed(int id) => {
      'entityType': 'feed',
      'entityId': id,
      'id': id,
      'uid': '1',
      'message': '内容 $id',
    };

/// A successful page built the same way the content-filter tests build one.
LoadingState page(List<int> ids) => NetworkRepo.handleListResponse(Response(
      requestOptions: RequestOptions(path: '/v6/feed/test'),
      statusCode: 200,
      data: {'data': ids.map(feed).toList()},
    ));

List<dynamic> idsOf(CommonController controller) {
  final state = controller.loadingState.value;
  if (state case Success(:final response)) {
    return (response as List).map((e) => e.id).toList();
  }
  return const [];
}

void main() {
  test('continuous pagination appends pages and ends on Empty', () async {
    final controller =
        ScriptedController([page([1, 2]), page([3, 4]), LoadingState.empty()]);
    await controller.onGetData();
    expect(idsOf(controller), [1, 2]);
    expect(controller.page, 2);
    expect(controller.isEnd, isFalse);
    await controller.onGetData(false);
    expect(idsOf(controller), [1, 2, 3, 4]);
    expect(controller.page, 3);
    await controller.onGetData(false);
    expect(idsOf(controller), [1, 2, 3, 4]);
    expect(controller.page, 3);
    expect(controller.isEnd, isTrue);
    expect(controller.isLoading, isFalse);
    expect(controller.calls, 3);
    controller.onClose();
  });

  test('failure mid-way keeps data, leaves isEnd false and stays retryable',
      () async {
    final error = LoadingState.error('网络异常');
    final controller = ScriptedController([
      page([1, 2]),
      error,
      page([3]),
    ]);
    await controller.onGetData();
    expect(idsOf(controller), [1, 2]);
    expect(controller.page, 2);
    await controller.onGetData(false);
    expect(idsOf(controller), [1, 2]);
    expect(controller.page, 2);
    expect(controller.isEnd, isFalse);
    expect(controller.isLoading, isFalse);
    expect(controller.automaticLoadPaused, isTrue);
    expect(controller.footerState.value, isA<Error>());
    await controller.onGetData(false);
    expect(idsOf(controller), [1, 2, 3]);
    expect(controller.page, 3);
    expect(controller.isEnd, isFalse);
    expect(controller.calls, 3);
    controller.onClose();
  });

  test('refresh replaces the list instead of appending', () async {
    final controller =
        ScriptedController([page([1, 2]), page([3, 4]), page([1, 2])]);
    await controller.onGetData();
    await controller.onGetData(false);
    expect(idsOf(controller), [1, 2, 3, 4]);
    expect(controller.page, 3);
    await controller.onGetData();
    expect(idsOf(controller), [1, 2]);
    expect(controller.page, 4);
    expect(controller.isEnd, isFalse);
    expect(controller.isLoading, isFalse);
    expect(controller.calls, 3);
    controller.onClose();
  });
}
