import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/logic/network/network_repo.dart';
import 'package:c001apk_flutter/logic/network/request.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Transport implements HttpClientAdapter {
  Map<String, dynamic> body = {
    'data': {'uid': '42', 'username': '测试用户'},
  };
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('profile silenced flag parsing', () {
    Datum parse(Map<String, dynamic> json) => Datum.fromJson(json);

    test('disallowPost == 1 marks the profile silenced', () {
      final data = parse({'uid': 32864090, 'disallowPost': 1});
      expect(data.isSilenced, isTrue);
    });

    test('normal, missing and zero values never mark silenced', () {
      expect(parse({'uid': 575232, 'disallowPost': 0}).isSilenced, isFalse);
      expect(parse({'uid': 575232}).isSilenced, isFalse);
      expect(parse({'uid': 575232, 'disallowPost': null}).isSilenced, isFalse);
      expect(parse({'uid': 575232, 'disallowPost': -1}).isSilenced, isFalse);
    });

    test('birthday and region round-trip for the edit form', () {
      final data = parse({
        'uid': 42,
        'bio': '签名',
        'gender': 1,
        'birthyear': 2000,
        'birthmonth': 6,
        'birthday': 15,
        'province': '浙江',
        'city': '杭州',
      });
      expect(data.birthyear, 2000);
      expect(data.birthmonth, 6);
      expect(data.birthday, 15);
      expect(data.province, '浙江');
      expect(data.city, '杭州');
    });
  });

  group('edit profile endpoints', () {
    late Directory temp;
    late _Transport transport;
    setUpAll(() async {
      temp = await Directory.systemTemp.createTemp('edit-profile-test-');
      Hive.init(temp.path);
      GStorage.settings = await Hive.openBox('settings');
      await GStorage.settings.putAll({
        SettingsBoxKey.xAppDevice: 'synthetic-edit-profile-device',
        SettingsBoxKey.versionCode: '2604201',
      });
      Request();
    });
    setUp(() {
      transport = _Transport();
      Request.dio.httpClientAdapter = transport;
    });
    tearDownAll(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });

    test('changeProfile posts key/value as a form', () async {
      await NetworkRepo.postChangeProfile(key: 'bio', value: '新签名');

      final request = transport.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v6/account/changeProfile');
      expect(request.contentType, Headers.formUrlEncodedContentType);
      expect(request.data, {'key': 'bio', 'value': '新签名'});
    });

    test('birthday posts an empty key with a JSON value', () async {
      await NetworkRepo.postChangeProfile(
          key: '', value: '{"birthyear":2000,"birthmonth":6,"birthday":15}');

      final request = transport.requests.single;
      expect(request.uri.path, '/v6/account/changeProfile');
      expect(request.data,
          {'key': '', 'value': '{"birthyear":2000,"birthmonth":6,"birthday":15}'});
    });

    test('resetProfile posts only the key', () async {
      await NetworkRepo.postResetProfile(key: 'birth');

      final request = transport.requests.single;
      expect(request.uri.path, '/v6/account/resetProfile');
      expect(request.data, {'key': 'birth'});
    });

    test('changeAvatarCover posts the full CDN url', () async {
      await NetworkRepo.postChangeAvatarCover(
          url: 'http://avatar.coolapk.com/cover/42_123.jpg');

      final request = transport.requests.single;
      expect(request.uri.path, '/v6/account/changeAvatarCover');
      expect(request.data, {'url': 'http://avatar.coolapk.com/cover/42_123.jpg'});
    });

    test('changeAvatar posts an imgFile multipart part', () async {
      await NetworkRepo.postChangeAvatar(file: MultipartFile.fromBytes(
        [1, 2, 3],
        filename: 'abc123',
      ));

      final request = transport.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v6/account/changeAvatar');
      expect(request.contentType,
          startsWith(Headers.multipartFormDataContentType));
      final fields = (request.data as FormData).fields.map((e) => e.key);
      final files = (request.data as FormData).files.map((e) => e.key);
      expect(fields, isEmpty);
      expect(files, ['imgFile']);
    });
  });
}
