import 'dart:io';
import 'dart:typed_data';

import 'package:c001apk_flutter/logic/network/api_failure.dart';
import 'package:c001apk_flutter/logic/network/interceptor.dart';
import 'package:c001apk_flutter/utils/global_data.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

// Same recording transport as request_test.dart: the interceptor runs, no
// real network is touched.
class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (requestStream != null) {
      await requestStream.expand((chunk) => chunk).toList();
    }
    return ResponseBody.fromString('{"data":[]}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory directory;
  late RecordingAdapter adapter;
  late Dio dio;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('c001apk-interceptor-');
    Hive.init(directory.path);
    GStorage.settings = await Hive.openBox('settings');
  });

  setUp(() async {
    await GStorage.settings.putAll({
      SettingsBoxKey.xAppDevice: 'synthetic-test-device',
      SettingsBoxKey.versionCode: '2604201',
      SettingsBoxKey.versionName: '16.2.0',
      SettingsBoxKey.apiVersion: '16',
      SettingsBoxKey.sdkInt: '33',
      SettingsBoxKey.userAgent: 'SyntheticTest/1.0',
    });
    await GStorage.settings.delete('apiSessionV1');
    await GStorage.settings.delete('apiValidationV1');
    GlobalData().isLogin = false;
    GlobalData().uid = '';
    GlobalData().username = '';
    GlobalData().token = '';
    GlobalData().loginSession = '';
    GlobalData().SESSID = '';
    GlobalData().sessionGeneration = 0;
    adapter = RecordingAdapter();
    dio = Dio()
      ..interceptors.add(ApiInterceptor())
      ..httpClientAdapter = adapter;
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('account login request gets web headers without an app token',
      () async {
    await dio.get('https://account.coolapk.com/auth/login?type=mobile');
    final headers = adapter.requests.single.headers;
    expect(headers['User-Agent'], 'SyntheticTest/1.0');
    expect(headers['X-Requested-With'], 'com.coolapk.market');
    expect(headers['Accept'], contains('text/html'));
    expect(headers['sec-ch-ua'], contains('Android WebView'));
    expect(headers, isNot(contains('X-App-Token')));
    expect(adapter.requests.single.responseType, ResponseType.plain);
  });

  test('account login POST uses the ajax request marker', () async {
    await dio.post('https://account.coolapk.com/auth/loginByCoolApk',
        data: {'submit': '1'});
    final headers = adapter.requests.single.headers;
    expect(headers['X-Requested-With'], 'XMLHttpRequest');
    expect(headers['User-Agent'], 'SyntheticTest/1.0');
    expect(headers, isNot(contains('X-App-Token')));
  });

  test('api guest request gets signed headers and an empty session cookie',
      () async {
    await dio.get('https://api.coolapk.com/v6/main/indexV8');
    final headers = adapter.requests.single.headers;
    expect(headers['X-App-Token'], startsWith('v3'));
    expect(headers['X-App-Id'], 'com.coolapk.market');
    expect(headers['X-Api-Version'], '16');
    expect(headers['X-App-Device'], 'synthetic-test-device');
    expect(headers['Cookie'], '');
  });

  test('api logged-in request carries the account in its cookie', () async {
    GlobalData().isLogin = true;
    GlobalData().uid = '123';
    GlobalData().username = 'tester';
    GlobalData().token = 'synthetic-token';
    await dio.get('https://api.coolapk.com/v6/account/checkLogin');
    final cookie = adapter.requests.single.headers['Cookie'] as String;
    expect(cookie, contains('uid=123'));
    expect(cookie, contains('username=tester'));
    expect(cookie, contains('token=synthetic-token'));
    expect(adapter.requests.single.headers['X-App-Token'], startsWith('v3'));
  });

  test('public feed request gets signed headers but no cookie', () async {
    await dio.get('https://www.coolapk.com/feed/123');
    final request = adapter.requests.single;
    expect(request.headers['X-App-Token'], startsWith('v3'));
    expect(request.headers, isNot(contains('Cookie')));
    expect(request.responseType, ResponseType.plain);
  });

  test('unrelated hosts pass through without client headers', () async {
    await dio.get('https://m.coolapk.com/mp/product/configInfo');
    final headers = adapter.requests.single.headers;
    expect(headers, isNot(contains('X-App-Token')));
    expect(headers, isNot(contains('X-App-Id')));
    expect(headers, isNot(contains('Cookie')));
  });

  test('stale session generation rejects before the request is sent',
      () async {
    await expectLater(
        dio.get('https://api.coolapk.com/v6/main/indexV8',
            options: Options(extra: {'sessionGeneration': 99})),
        throwsA(isA<DioException>()
            .having((error) => error.type, 'type', DioExceptionType.cancel)
            .having((error) => error.error, 'error', '账号已切换')));
    expect(adapter.requests, isEmpty);
  });

  test('matching session generation proceeds', () async {
    await dio.get('https://api.coolapk.com/v6/main/indexV8',
        options: Options(extra: {'sessionGeneration': 0}));
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.headers['X-App-Token'], startsWith('v3'));
  });

  test('unparseable version code rejects as a client error', () async {
    await GStorage.settings.put(SettingsBoxKey.versionCode, 'not-a-number');
    await expectLater(
        dio.get('https://api.coolapk.com/v6/main/indexV8'),
        throwsA(isA<DioException>().having(
            (error) => error.error,
            'error',
            isA<ApiFailure>()
                .having((failure) => failure.kind, 'kind',
                    ApiFailureKind.business)
                .having((failure) => failure.message, 'message',
                    '请求参数异常，请检查客户端协议设置和系统时间'))));
    expect(adapter.requests, isEmpty);
  });

  test('dioError maps common failures to safe local messages', () async {
    DioException error(DioExceptionType type, {int? status}) => DioException(
        requestOptions: RequestOptions(path: '/v6/test'),
        type: type,
        response: status == null
            ? null
            : Response(
                requestOptions: RequestOptions(path: '/v6/test'),
                statusCode: status));
    expect(await ApiInterceptor.dioError(
        error(DioExceptionType.connectionTimeout)), '请求超时，请稍后重试');
    expect(
        await ApiInterceptor.dioError(
            error(DioExceptionType.badResponse, status: 404)),
        contains('HTTP 404'));
    expect(await ApiInterceptor.dioError(error(DioExceptionType.cancel)),
        '请求已取消');
    expect(
        await ApiInterceptor.dioError(DioException(
            requestOptions: RequestOptions(path: '/v6/test'),
            type: DioExceptionType.unknown,
            error: const FormatException('bad json'))),
        '服务器响应格式异常，请稍后重试');
  });

  test('concurrent account and api requests keep their own headers',
      () async {
    await Future.wait([
      dio.get('https://account.coolapk.com/auth/login?type=mobile'),
      dio.get('https://api.coolapk.com/v6/main/indexV8'),
    ]);
    final account = adapter.requests
        .singleWhere((request) => request.uri.host == 'account.coolapk.com');
    final api = adapter.requests
        .singleWhere((request) => request.uri.host == 'api.coolapk.com');
    expect(account.headers, isNot(contains('X-App-Token')));
    expect(account.headers['Accept'], contains('text/html'));
    expect(api.headers['X-App-Token'], startsWith('v3'));
  });
}
