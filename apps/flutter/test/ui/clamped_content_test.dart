import 'package:c001apk_flutter/components/clamped_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stripHtml 去掉标签文本，纯文本原样返回', () {
    expect(ClampedHtml.stripHtml('普通文本'), '普通文本');
    expect(ClampedHtml.stripHtml('<p>第一段</p><p>第二段</p>'), '第一段第二段');
    expect(ClampedHtml.stripHtml('<b>加粗</b>与<a href="/t/x">#话题#</a>'),
        '加粗与#话题#');
  });

  testWidgets('短文本不折叠也不出现查看更多', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ClampedHtml(
      plainText: '短正文',
      maxLines: 5,
      onMore: () {},
      child: const Text('短正文'),
    ))));
    expect(find.text('短正文'), findsOneWidget);
    expect(find.text('查看更多'), findsNothing);
  });

  testWidgets('超长文本折叠并出现查看更多，点击回调', (tester) async {
    var opened = 0;
    final long = List.generate(40, (i) => '第 $i 行正文内容').join('\n');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: ClampedHtml(
        plainText: long,
        maxLines: 5,
        onMore: () => opened++,
        child: Text(long),
      ),
    ))));
    expect(find.text('查看更多'), findsOneWidget);
    await tester.tap(find.text('查看更多'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('签名超过两行才显示展开，展开后可收起', (tester) async {
    final longBio = List.generate(6, (i) => '签名第 $i 行').join('\n');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpandableBio(text: longBio, padding: EdgeInsets.zero))));
    expect(find.text('展开'), findsOneWidget);
    await tester.tap(find.text('展开'));
    await tester.pumpAndSettle();
    expect(find.text('收起'), findsOneWidget);
  });

  testWidgets('一行签名不显示展开按钮', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ExpandableBio(text: '简短签名', padding: EdgeInsets.zero))));
    expect(find.text('展开'), findsNothing);
    expect(find.text('简短签名'), findsOneWidget);
  });
}
