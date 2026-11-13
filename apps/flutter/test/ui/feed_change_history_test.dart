import 'package:c001apk_flutter/pages/feed/feed_change_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseFeedChangeHistory', () {
    test('current, edited and original versions are labelled', () {
      final items = parseFeedChangeHistory([
        {
          'isHistory': 0,
          'message': '最新正文',
          'last_change_time': 1761888000,
        },
        {
          'isHistory': 1,
          'change_count': 1,
          'message': '第一次正文',
          'message_title': '旧标题',
          'last_change_time': 1761801600,
          'picArr': ['https://example.com/a.jpg'],
        },
        {
          'isHistory': 1,
          'message': '原始正文',
        },
      ]);
      expect(items.length, 3);
      expect(items[0].versionLabel, '当前版本');
      expect(items[0].isCurrent, isTrue);
      expect(items[0].timeMillis, 1761888000 * 1000);
      expect(items[1].versionLabel, '第 1 次编辑');
      expect(items[1].title, '旧标题');
      expect(items[1].images, ['https://example.com/a.jpg']);
      expect(items[2].versionLabel, '原始版本');
    });

    test('html markup is stripped and non-list payload is empty', () {
      final items = parseFeedChangeHistory([
        {'isHistory': 0, 'message': '<p>带<b>标签</b>的正文</p>'},
      ]);
      expect(items[0].content, '带标签的正文');
      expect(parseFeedChangeHistory('nonsense'), isEmpty);
      expect(parseFeedChangeHistory(null), isEmpty);
    });
  });

  group('feedChangeBadge', () {
    FeedChangeHistoryItem item(String content) => FeedChangeHistoryItem(
          isCurrent: true,
          changeCount: 0,
          title: '',
          content: content,
          images: const [],
        );

    test('identical text, added text and deleted text', () {
      expect(feedChangeBadge(item('同样'), item('同样')), '文本无改动');
      expect(feedChangeBadge(item('同样多了字'), item('同样')), '+3字');
      expect(feedChangeBadge(item('同样'), item('同样多了字')), '-3字');
      expect(feedChangeBadge(item('甲乙'), item('丙丁')), '文本有改动');
      expect(feedChangeBadge(item('只有当前'), null), isNull);
    });
  });
}
