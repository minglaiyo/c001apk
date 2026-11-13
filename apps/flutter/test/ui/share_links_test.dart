import 'package:c001apk_flutter/router/link_resolver.dart';
import 'package:c001apk_flutter/utils/share_util.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('article share has a one-line title and both encoded links', () {
    expect(getShareText('123', ShareType.feed, title: '文章\n标题'),
        '文章 标题\nhttps://www.coolapk1s.com/feed/123\nhttps://www.coolapk.com/feed/123\n分享自c001apk');
    expect(getShareText('摄影 & 日常', ShareType.t, title: '摄影话题'),
        '摄影话题\nhttps://www.coolapk1s.com/t/%E6%91%84%E5%BD%B1%20%26%20%E6%97%A5%E5%B8%B8\nhttps://www.coolapk.com/t/%E6%91%84%E5%BD%B1%20%26%20%E6%97%A5%E5%B8%B8\n分享自c001apk');
  });

  test('untitled feeds use plain text with a safe empty fallback', () {
    expect(
        getShareText('123', ShareType.feed,
                message: '<p>第一行<br>第二行 &amp; 内容</p>')
            .split('\n')
            .first,
        '第一行 第二行 & 内容');
    expect(getShareText('123', ShareType.feed).split('\n').first, '动态');
  });


  for (final link in [
    'coolmarket://www.coolapk.com/feed/123?s=x#reply',
    'coolmarket://com.coolapk.market/feed/123',
    'https://m.coolapk.com/feed/123?s=x',
    'https://www.coolapk1s.com/feed/123',
  ]) {
    testWidgets('external link $link opens the normalized feed',
        (tester) async {
      await tester.pumpWidget(GetMaterialApp(initialRoute: '/', getPages: [
        GetPage(name: '/', page: () => const Scaffold(body: Text('主页'))),
        GetPage(
            name: '/feed/:id',
            page: () => Scaffold(body: Text('动态 ${Get.parameters['id']}'))),
      ]));
      await tester.pumpAndSettle();
      openLink(link);
      await tester.pumpAndSettle();
      expect(find.text('动态 123'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Get.back();
      await tester.pumpAndSettle();
      expect(find.text('主页'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final example in [
    ('https://m.coolapk.com/u/123?s=x#profile', '/u/:value', '123'),
    (
      'coolmarket://www.coolapk.com/apk/com.tencent.mm?s=x',
      '/apk/:value',
      'com.tencent.mm'
    ),
    (
      'https://www.coolapk.com/t/%E6%91%84%E5%BD%B1%20%26%20%E6%97%A5%E5%B8%B8?s=x#reply',
      '/t/:value',
      '摄影 & 日常'
    ),
    ('coolmarket://product/123?s=x', '/product/:value', '123'),
  ]) {
    testWidgets('non-feed link ${example.$1} strips metadata and decodes once',
        (tester) async {
      await tester.pumpWidget(GetMaterialApp(initialRoute: '/', getPages: [
        GetPage(name: '/', page: () => const Scaffold(body: Text('主页'))),
        GetPage(
            name: example.$2,
            page: () => Scaffold(body: Text('目标 ${Get.parameters['value']}'))),
      ]));
      await tester.pumpAndSettle();
      openLink(example.$1);
      await tester.pumpAndSettle();
      expect(find.text('目标 ${example.$3}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
