import 'package:c001apk_flutter/pages/feed/reply/rating_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(ValueChanged<RatingFormValue> onChanged,
      {List<Map<String, dynamic>> items = const [
        {'id': 'v4_score_item_1', 'name': '续航'},
        {'id': 'v4_score_item_2', 'name': '屏幕'},
      ]}) {
    return MaterialApp(
        home: Scaffold(
            body: RatingPanel(
                target: '合成手机', items: items, onChanged: onChanged)));
  }

  testWidgets('总体与全部子项未打分时 valid 为 false', (tester) async {
    RatingFormValue? value;
    await tester.pumpWidget(host((v) => value = v));
    expect(find.text('合成手机'), findsOneWidget);
    expect(find.text('总体评分'), findsOneWidget);
    expect(find.text('续航'), findsOneWidget);
    // 未点击星标前不会派发回调，表单视为无效。
    expect(value, isNull);
  });

  testWidgets('打满总体与子项后 valid 为 true 且星数正确', (tester) async {
    RatingFormValue? value;
    await tester.pumpWidget(host((v) => value = v));
    // 三行星级：总体 + 两个子项，每行 5 颗星。
    final stars = find.byIcon(Icons.star_border);
    expect(stars, findsNWidgets(15));
    // 第一行（总体）点第 4 颗。
    await tester.tap(stars.at(3));
    await tester.pumpAndSettle();
    // 其余两行各点第 5 颗（索引随已填充图标偏移，改用 tooltip 定位）。
    await tester.tap(find.byTooltip('5 星').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 星').at(2));
    await tester.pumpAndSettle();
    expect(value?.overall, 4);
    expect(value?.itemStars, [5, 5]);
    expect(value?.valid, isTrue);
  });

  testWidgets('优缺点文本与已购买参与表单', (tester) async {
    RatingFormValue? value;
    await tester.pumpWidget(host((v) => value = v));
    await tester.enterText(find.widgetWithText(TextField, '优点').first, '手感好');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '缺点').first, '略重');
    await tester.pumpAndSettle();
    await tester.tap(find.text('已购买'));
    await tester.pumpAndSettle();
    expect(value?.good, '手感好');
    expect(value?.bad, '略重');
    expect(value?.buyStatus, isTrue);
  });

  test('valid 要求每个子项都 >0', () {
    const missing = RatingFormValue(
        overall: 5, itemStars: [5, 0], good: '', bad: '', buyStatus: false);
    expect(missing.valid, isFalse);
    const complete = RatingFormValue(
        overall: 5, itemStars: [5, 4], good: '', bad: '', buyStatus: false);
    expect(complete.valid, isTrue);
    const noItems = RatingFormValue(
        overall: 5, itemStars: [], good: '', bad: '', buyStatus: false);
    expect(noItems.valid, isFalse);
  });
}
