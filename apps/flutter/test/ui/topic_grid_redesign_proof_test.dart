import 'dart:io';

import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/pages/home/topic/topic_grid_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 新版话题/数码格子页的视觉预览（左栏胶囊 + 分段排序 + 卡片格子）。
/// 仅 Windows 本机生成 PNG（golden 跨平台不一致），不进 CI。
void main() {
  testWidgets(
    '生成新版格子页预览',
    skip: !Platform.isWindows,
    (tester) async {
      final items = [
        {'title': '薅羊毛小分队', 'hot_num_txt': '323.3万', 'logo': ''},
        {'title': '今日热点', 'hot_num_txt': '183.9万', 'logo': ''},
        {'title': '鸿蒙7', 'hot_num_txt': '182.4万', 'logo': ''},
        {'title': 'HyperOS4', 'hot_num_txt': '133.1万', 'logo': ''},
        {'title': 'ColorOS17', 'hot_num_txt': '126.8万', 'logo': ''},
        {'title': '酷安夜话', 'hot_num_txt': '98.1万', 'logo': ''},
        {'title': '临时root免解BL锁', 'hot_num_txt': '72.6万', 'logo': ''},
        {'title': '数码日常', 'hot_num_txt': '88.3万', 'logo': ''},
        {'title': '酷工作', 'hot_num_txt': '51.5万', 'logo': ''},
      ]
          .map((e) => Datum.fromJson(e))
          .toList();

      const categories = [
        '推荐',
        '热门',
        '我的关注',
        '值得买',
        '摄影',
        '系统',
        '玩机',
        '苹果',
        '电脑',
        '配件',
      ];

      Widget rail() {
        return ColoredBox(
          color: const Color(0xFFFDFDF8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < categories.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 1
                              ? const Color(0xFFD9E7D3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1,
                            fontWeight: i == 1
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == 1
                                ? const Color(0xFF2C4A2A)
                                : const Color(0xFF5A5F58),
                          ),
                          child: Text(categories[i]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: rail(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 排序分段控件（选中「热门」态展示滑块位置）。
                      const _SortTogglePreview(),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 470,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            mainAxisExtent: 148,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) => TopicGridCell(
                            data: items[index],
                            onTap: () {},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/topic_grid_redesign.png'),
      );
    },
  );
}

/// _SortToggle 在 topic_grid_page.dart 里是私有的，这里按同样结构
/// 复刻一份用于预览（不引入对私有组件的依赖）。
class _SortTogglePreview extends StatelessWidget {
  const _SortTogglePreview();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.onInverseSurface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.centerLeft,
            child: Container(
              width: 64,
              height: 28,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in const [
                MapEntry('默认', true),
                MapEntry('热度', false),
              ])
                Container(
                  width: 64,
                  height: 28,
                  alignment: Alignment.center,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1,
                      fontWeight:
                          entry.value ? FontWeight.w600 : FontWeight.w400,
                      color: entry.value
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
