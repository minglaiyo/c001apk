import 'dart:io';

import 'package:c001apk_flutter/components/clamped_content.dart';
import 'package:c001apk_flutter/components/markdown_body.dart';
import 'package:c001apk_flutter/components/rich_preview.dart';
import 'package:c001apk_flutter/components/html_text.dart';
import 'package:c001apk_flutter/utils/html_text_util.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  // 真实渲染链路测试需要 showEmoji 读 settings box。
  setUpAll(() async {
    final temp =
        await Directory.systemTemp.createTemp('clamped-content-');
    Hive.init(temp.path);
    GStorage.settings = await Hive.openBox('settings');
  });
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

    testWidgets('真实 htmlText 链路（话题链接+换行）缩放 1.2 下 5 行完整保留',
        (tester) async {
      // 模拟真实动态正文结构：话题 <a> 行内标签 + 换行 <br> + 短行正文
      // （每行 ≤16 字，360 宽、1.2 倍缩放下不二次折行，行界确定）。
      final message = '<a class="feed-link-topic" href="/t/笔记本电脑">'
          '#笔记本电脑#</a> <a class="feed-link-topic" href="/t/电脑玩家">'
          '#电脑玩家#</a>\n'
          '${List.generate(7, (i) => '正文第 $i 行内容用于测试').join('\n')}';
      const scaler = TextScaler.linear(1.2);
      const bodyStyle = TextStyle(fontSize: 16, height: 1.5);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: scaler),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 行高参照：与正文同样式、同缩放的单行。
                  const Text('参照行', style: bodyStyle, textDirection: TextDirection.ltr),
                  SizedBox(
                    width: 360,
                    child: ClampedHtml(
                      // 与生产一致的量行口径。
                      plainText:
                          ClampedHtml.stripHtml(parseHtmlString(message)),
                      maxLines: 5,
                      fontSize: 16,
                      height: 1.5,
                      onMore: () {},
                      child: htmlText(message,
                          fontSize: 16, lineHeight: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      expect(find.text('查看更多'), findsOneWidget);

      final lineHeight =
          tester.getSize(find.text('参照行')).height;
      final clip = tester.getSize(find
          .descendant(
              of: find.byType(ClampedHtml), matching: find.byType(ClipRect))
          .first);
      // 裁切框装得下渲染端前 5 行（每行取整误差 ≤1 物理像素/行），
      // 且确实只裁到 5 行附近（不是把整块都放出来了）。
      expect(clip.height, greaterThanOrEqualTo(5 * lineHeight - 1.5));
      expect(clip.height, lessThanOrEqualTo(6 * lineHeight));
    });

    group('FeedText markdown 预览（原生 maxLines 截断）', () {
      // 超过 5 行的 markdown 正文（引用 + 列表结构，与真实动态一致）。
      final longMarkdown =
          '> 引用内容用于小窗说明\n${List.generate(8, (i) => '- 新增测试条目第 $i 行内容').join('\n')}';

      Future<void> pumpFeedText(
          WidgetTester tester, String markdown,
          {TextScaler scaler = TextScaler.noScaling,
          void Function()? onMore}) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: scaler),
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 300,
                  child: FeedText(
                    markdown,
                    preview: true,
                    previewMaxLines: 5,
                    onPreviewMore: onMore,
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
      }

      testWidgets('长 markdown 折到 5 行：原生 maxLines，全链路无 ClipRect',
          (tester) async {
        var opened = 0;
        await pumpFeedText(tester, longMarkdown, onMore: () => opened++);
        expect(find.text('查看更多'), findsOneWidget);
        // 预览 Text 的 maxLines 就是 5（截断由文本引擎自己做，任何缩放下
        // 都不会切掉半个字）——这正是放弃手工 ClipRect 的意义。
        final previewText = tester.widgetList<Text>(find.byType(Text)).first;
        expect(previewText.maxLines, 5);
        expect(find.descendant(of: find.byType(FeedText), matching: find.byType(ClipRect)), findsNothing);
        await tester.tap(find.text('查看更多'));
        expect(opened, 1);
      });

      testWidgets('短 markdown 不折叠、无查看更多', (tester) async {
        await pumpFeedText(tester, '> 一行小窗\n- 一个短条目');
        expect(find.text('查看更多'), findsNothing);
        expect(find.descendant(of: find.byType(FeedText), matching: find.byType(ClipRect)), findsNothing);
      });

      testWidgets('缩放 1.3 下同样只依赖原生截断', (tester) async {
        await pumpFeedText(tester, longMarkdown,
            scaler: const TextScaler.linear(1.3), onMore: () {});
        expect(find.text('查看更多'), findsOneWidget);
        expect(find.descendant(of: find.byType(FeedText), matching: find.byType(ClipRect)), findsNothing);
        final previewText = tester.widgetList<Text>(find.byType(Text)).first;
        expect(previewText.maxLines, 5);
      });
    });
  });

  group('RichPreview（非 markdown 预览，原生 maxLines 截断）', () {
    // 与真实动态一致的结构：话题 <a> + 表情 token + <br> 换行 + 长正文。
    final html =
        '<a class="feed-link-topic" href="/t/笔记本电脑">#笔记本电脑#</a> '
        '<a class="feed-link-topic" href="/t/电脑玩家">#电脑玩家#</a><br/>'
        '[呲牙]中国自己的An网→闲鱼<br/>'
        '${List.generate(9, (i) => '正文第 $i 行，这里有一段足够长的文字用于折行测试。').join('<br/>')}';

    Future<void> pumpPreview(WidgetTester tester, TextScaler scaler,
        {required void Function() onMore}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: scaler),
            child: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: RichPreview(
                  source: html,
                  maxLines: 5,
                  fontSize: 16,
                  lineHeight: 1.5,
                  onMore: onMore,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('长正文折到 5 行：原生 maxLines，子树无 ClipRect，回调可用',
        (tester) async {
      var opened = 0;
      await pumpPreview(tester, TextScaler.noScaling, onMore: () => opened++);
      expect(find.text('查看更多'), findsOneWidget);
      final previewText = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(RichPreview), matching: find.byType(Text)))
          .first;
      expect(previewText.maxLines, 5);
      expect(find.descendant(of: find.byType(RichPreview), matching: find.byType(ClipRect)),
          findsNothing);
      await tester.tap(find.text('查看更多'));
      expect(opened, 1);
    });

    testWidgets('话题链接渲染为主题色、表情渲染为占位图', (tester) async {
      await pumpPreview(tester, TextScaler.noScaling, onMore: () {});
      // 话题文本在 span 树里着主题色、表情在树里是 WidgetSpan：递归检查。
      final rich = tester.widgetList<RichText>(find.byType(RichText));
      final topicTexts = <String>{};
      final linkTopics = <String>{};
      var hasEmoji = false;
      void walk(InlineSpan span, bool link) {
        if (span is WidgetSpan) {
          hasEmoji = true;
          return;
        }
        if (span is TextSpan) {
          final isLink = link ||
              span.style?.decoration == TextDecoration.none &&
                  span.style?.color != null;
          if ((span.text ?? '').isNotEmpty) {
            topicTexts.add(span.text!);
            if (isLink) linkTopics.add(span.text!);
          }
          for (final c in span.children ?? const <InlineSpan>[]) {
            walk(c, isLink);
          }
        }
      }
      for (final r in rich) {
        final root = r.text;
        if (root is TextSpan) walk(root, false);
      }
      expect(topicTexts.any((t) => t.contains('#笔记本电脑#')), isTrue,
          reason: '话题文本应出现在 span 树里');
      expect(linkTopics.any((t) => t.contains('#笔记本电脑#')), isTrue,
          reason: '话题应为主题色链接样式');
      expect(hasEmoji, isTrue, reason: '表情应为 WidgetSpan 占位图');
    });

    testWidgets('缩放 1.3 下同样只依赖原生截断', (tester) async {
      await pumpPreview(tester, const TextScaler.linear(1.3), onMore: () {});
      expect(find.text('查看更多'), findsOneWidget);
      final previewText = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(RichPreview), matching: find.byType(Text)))
          .first;
      expect(previewText.maxLines, 5);
      expect(find.descendant(of: find.byType(RichPreview), matching: find.byType(ClipRect)),
          findsNothing);
    });

    testWidgets('短正文不折叠、无查看更多', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RichPreview(
                  source: '[呲牙]短正文一条',
                  maxLines: 5,
                  onMore: () {}))));
      expect(find.text('查看更多'), findsNothing);
    });
  });
}