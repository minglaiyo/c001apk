import 'package:c001apk_flutter/components/clamped_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 视觉证据：同一篇正文、同一种字体缩放（1.2 倍），
/// 左右对比「修复前的裁切算法」与「修复后（当前代码）」的渲染结果。
/// 用 `flutter test --update-goldens test/ui/truncation_proof_test.dart`
/// 生成 PNG。
void main() {
  testWidgets('生成修复前后对比图', (tester) async {
    const bodyStyle = TextStyle(fontSize: 16, height: 1.5);
    const text = '中国自己的An网→闲鱼\n'
        '以158购入小米新国标充电宝Pro，无后盖背板功能完好，'
        '不可****正常配对，使用小方法完成配对。\n'
        '经测试．大多功能正常，充电功率134W，下载曲线见附图。\n'
        '拆解发现电芯为暴力拆解，排线插头完好。\n'
        '评论区投币自取，仅限自取，谢谢配合。';

    Widget label(String s) => Text(s,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black));

    // 修复前的算法：裁切高度按未缩放字号硬算（5 × 16 × 1.5 = 120px）。
    final oldRendering = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        label('修复前（你手机上的表现）：'),
        const SizedBox(height: 4),
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFE8E8DE)),
          child: SizedBox(
            height: 5 * 16 * 1.5,
            width: double.infinity,
            child: ClipRect(
              child: Text(text,
                  style: bodyStyle, textDirection: TextDirection.ltr),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text('查看更多',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3A6B35))),
      ],
    );

    // 修复后的算法：当前 ClampedHtml（量行与裁高带渲染端同一 textScaler）。
    final newRendering = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        label('修复后（1.7.2 构建）：'),
        const SizedBox(height: 4),
        Material(
          color: const Color(0xFFE8E8DE),
          child: ClampedHtml(
            plainText: ClampedHtml.stripHtml(text),
            maxLines: 5,
            fontSize: 16,
            height: 1.5,
            onMore: () {},
            child: const Text(text,
                style: bodyStyle, textDirection: TextDirection.ltr),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('设备字体 1.2 倍时的列表卡正文：',
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 8),
                oldRendering,
                const SizedBox(height: 16),
                newRendering,
              ],
            ),
          ),
        ),
      ),
    ));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/truncation_fix_proof.png'),
    );
  });
}
