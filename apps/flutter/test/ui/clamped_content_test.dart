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

  group('字体缩放下的裁切（回归：最后一行底部被切）', () {
    const bodyStyle = TextStyle(fontSize: 16, height: 1.5);
    final longText =
        '这是一段用来测试字体缩放下折行裁切高度的酷安动态正文内容。' * 8;

    double clippedHeight(WidgetTester tester) {
      final box = tester.widget<ConstrainedBox>(find
          .descendant(
              of: find.byType(ClampedHtml), matching: find.byType(ConstrainedBox))
          .first);
      return box.constraints.maxHeight;
    }

    Future<void> pumpClamped(
        WidgetTester tester, TextScaler scaler) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: scaler),
            child: SingleChildScrollView(
              child: SizedBox(
                // 240 宽 ≈ 15 字/行，确保长文本明显超过 5 行。
                width: 240,
                child: ClampedHtml(
                  plainText: longText,
                  maxLines: 5,
                  fontSize: 16,
                  height: 1.5,
                  onMore: () {},
                  child: Text(longText, style: bodyStyle),
                ),
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('未缩放时裁切高度是 5 行（120px）', (tester) async {
      await pumpClamped(tester, TextScaler.noScaling);
      expect(find.text('查看更多'), findsOneWidget);
      expect(clippedHeight(tester), closeTo(5 * 16 * 1.5, 0.1));
    });

    testWidgets('缩放 1.2 时裁切高度按实际行高放大，5 行完整保留',
        (tester) async {
      await pumpClamped(tester, const TextScaler.linear(1.2));
      expect(find.text('查看更多'), findsOneWidget);
      // 关键回归点：裁切高度必须随缩放走，且不小于 5 行的精确高度
      // （5×16×1.5×1.2 = 144）。行高取自与渲染端同一套字型度量，
      // 允许物理像素取整带来的 ≤1px/行 偏差——取整只会让裁切框
      // 略大于精确值，不会切进最后一行。
      final height = clippedHeight(tester);
      expect(height, greaterThanOrEqualTo(5 * 16 * 1.5 * 1.2 - 0.1));
      expect(height, lessThan(5 * 16 * 1.5 * 1.2 + 5));
      // 裁出来的盒子装得下 5 行渲染文本（渲染盒与裁切框一致）。
      final clip = tester.getSize(find
          .descendant(
              of: find.byType(ClampedHtml), matching: find.byType(ClipRect))
          .first);
      expect(clip.height, closeTo(height, 0.1));
    });

    testWidgets('签名展开判定跟随缩放：1.0 倍两行不展开，1.2 倍三行才展开',
        (tester) async {
      // 纯汉字 26 个：宽度 200 时 1.0 倍每行 14 字（2 行），
      // 1.2 倍每行约 11 字（3 行）。
      const bio = '这是一条用来验证字体缩放展开判定的签名文本内容';
      const unscaled = MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 200,
                  child: ExpandableBio(text: bio, padding: EdgeInsets.zero))));
      const scaled = MaterialApp(
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(1.2)),
                  child: SizedBox(
                      width: 200,
                      child:
                          ExpandableBio(text: bio, padding: EdgeInsets.zero)))));
      await tester.pumpWidget(unscaled);
      expect(find.text('展开'), findsNothing);

      await tester.pumpWidget(scaled);
      expect(find.text('展开'), findsOneWidget);
    });
  });
}
