import 'package:c001apk_flutter/components/product_discussion_sort_bar.dart';
import 'package:c001apk_flutter/pages/topic/topic_order_controller.dart';
import 'package:c001apk_flutter/pages/topic/topic_page.dart' show TopicSortType;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TopicOrderController controller;

  setUp(() {
    controller = TopicOrderController();
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductDiscussionSortBar(controller: controller),
          ),
        ),
      );

  testWidgets('renders default, latest and hot segments, default selected',
      (tester) async {
    await mount(tester);
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('最新'), findsOneWidget);
    expect(find.text('热度'), findsOneWidget);
    expect(controller.topicSortType.value, TopicSortType.DEFAULT);
    final button = tester.widget<SegmentedButton<TopicSortType>>(
        find.byType(SegmentedButton<TopicSortType>));
    expect(button.selected, <TopicSortType>{TopicSortType.DEFAULT});
  });

  testWidgets('tapping latest switches the shared sort state',
      (tester) async {
    await mount(tester);
    await tester.tap(find.text('最新'));
    await tester.pumpAndSettle();
    expect(controller.topicSortType.value, TopicSortType.DATELINE);
    final button = tester.widget<SegmentedButton<TopicSortType>>(
        find.byType(SegmentedButton<TopicSortType>));
    expect(button.selected, <TopicSortType>{TopicSortType.DATELINE});
  });

  testWidgets('tapping hot switches the shared sort state', (tester) async {
    await mount(tester);
    await tester.tap(find.text('热度'));
    await tester.pumpAndSettle();
    expect(controller.topicSortType.value, TopicSortType.HOT);
  });

  testWidgets('external sort change is reflected in the bar',
      (tester) async {
    await mount(tester);
    controller.setTopicSortType(TopicSortType.HOT);
    await tester.pumpAndSettle();
    final button = tester.widget<SegmentedButton<TopicSortType>>(
        find.byType(SegmentedButton<TopicSortType>));
    expect(button.selected, <TopicSortType>{TopicSortType.HOT});
  });
}
