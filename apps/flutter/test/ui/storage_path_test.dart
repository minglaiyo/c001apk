import 'dart:io';

import 'package:c001apk_flutter/utils/storage_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  setUp(() async =>
      temp = await Directory.systemTemp.createTemp('c001apk-path-'));
  tearDown(() async => temp.delete(recursive: true));

  test('hive 数据落在应用支持目录的 hive 子目录', () async {
    final current = Directory('${temp.path}/c001apk');
    expect(await resolveHivePath(current), '${current.path}/hive');
  });
}
