import 'package:c001apk_flutter/pages/topic/discussion_sort_url.dart';
import 'package:c001apk_flutter/pages/topic/topic_page.dart' show TopicSortType;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isTopicDiscussionUrl', () {
    test('plain tagFeedList url with sort card', () {
      expect(
        isTopicDiscussionUrl(
            '/page?url=/topic/tagFeedList?tag=小米&withSortCard=1'),
        isTrue,
      );
    });

    test('url-encoded tagFeedList url is decoded before matching', () {
      expect(
        isTopicDiscussionUrl(
            '/page?url=%2Ftopic%2FtagFeedList%3Ftag%3D%E5%B0%8F%E7%B1%B3%26withSortCard%3D1'),
        isTrue,
      );
    });

    test('tagFeedList without sort card is not sortable', () {
      expect(
        isTopicDiscussionUrl('/page?url=/topic/tagFeedList?tag=小米'),
        isFalse,
      );
    });

    test('product feedList is not a topic discussion', () {
      expect(
        isTopicDiscussionUrl('/page?url=/product/feedList?type=feed&id=1'),
        isFalse,
      );
    });
  });

  group('topicDiscussionSortUrl', () {
    const base =
        '/page?url=/topic/tagFeedList?tag=小米&withSortCard=1';

    test('appends sortField for each sort type', () {
      expect(
        topicDiscussionSortUrl(base, TopicSortType.DEFAULT),
        '$base&sortField=lastupdate_desc',
      );
      expect(
        topicDiscussionSortUrl(base, TopicSortType.DATELINE),
        '$base&sortField=dateline_desc',
      );
      expect(
        topicDiscussionSortUrl(base, TopicSortType.HOT),
        '$base&sortField=rank_score',
      );
    });

    test('replaces an existing sortField instead of appending', () {
      expect(
        topicDiscussionSortUrl(
            '$base&sortField=dateline_desc', TopicSortType.HOT),
        '$base&sortField=rank_score',
      );
    });

    test('re-sorting an already sorted url is idempotent', () {
      final once = topicDiscussionSortUrl(base, TopicSortType.DATELINE);
      expect(
        topicDiscussionSortUrl(once, TopicSortType.DATELINE),
        once,
      );
    });
  });

  group('productDiscussionSortUrl', () {
    test('matches the previous product sort urls exactly', () {
      expect(
        productDiscussionSortUrl('123', TopicSortType.DEFAULT),
        '/page?url=/product/feedList?type=feed&id=123&ignoreEntityById=1',
      );
      expect(
        productDiscussionSortUrl('123', TopicSortType.DATELINE),
        '/page?url=/product/feedList?type=feed&id=123&ignoreEntityById=1&listType=dateline_desc',
      );
      expect(
        productDiscussionSortUrl('123', TopicSortType.HOT),
        '/page?url=/product/feedList?type=feed&id=123&listType=rank_score',
      );
    });
  });

  test('discussionSortLabel uses the short labels', () {
    expect(discussionSortLabel(TopicSortType.DEFAULT), '默认');
    expect(discussionSortLabel(TopicSortType.DATELINE), '最新');
    expect(discussionSortLabel(TopicSortType.HOT), '热度');
  });
}
