import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/pages/home/topic/topic_grid_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Datum _datum(Map<String, dynamic> json) => Datum.fromJson(json);

void main() {
  group('topicGridItems', () {
    final items = [
      _datum({'entityType': 'topic', 'title': '酷安夜话'}),
      _datum({'entityType': 'product', 'title': '一加 Ace 7'}),
      _datum({'entityType': 'card', 'title': '轮播'}),
      _datum({'entityType': 'feed', 'title': '动态'}),
      _datum({'entityType': 'topic', 'title': 'HyperOS4'}),
    ];

    test('keeps only topic entries for the 话题 tab', () {
      final result = topicGridItems(items, 'topic');
      expect(
        result.map((item) => item.title).toList(),
        ['酷安夜话', 'HyperOS4'],
      );
    });

    test('keeps only product entries for the 数码 tab', () {
      final result = topicGridItems(items, 'product');
      expect(
        result.map((item) => item.title).toList(),
        ['一加 Ace 7'],
      );
    });
  });

  group('TopicGridCell', () {
    testWidgets('renders icon name and hot count, tap opens it',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicGridCell(
              data: _datum({
                'entityType': 'topic',
                'title': '酷安夜话',
                'logo': '',
                // Datum maps this field from the JSON key 'hot_num_txt'
                // (@JsonKey), not 'hotNumTxt': using the wrong key made
                // the count row vanish and the test fail with 0 matches.
                'hot_num_txt': '149.2万',
              }),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('酷安夜话'), findsOneWidget);
      expect(find.text('149.2万'), findsOneWidget);
      expect(find.byIcon(Icons.whatshot), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('hides the count row when hot count is missing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicGridCell(
              data: _datum({
                'entityType': 'topic',
                'title': '无热度话题',
                'logo': '',
              }),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('无热度话题'), findsOneWidget);
      expect(find.byIcon(Icons.whatshot), findsNothing);
    });
  });
}
