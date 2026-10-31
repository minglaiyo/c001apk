import 'package:c001apk_flutter/pages/product/product_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseProductDetail', () {
    test('header fields, score and specs are read from aliases', () {
      final detail = parseProductDetail('123', {
        'index_title': '小米15',
        'product_logo': 'https://example.com/logo.png',
        'device_info': '旗舰直屏',
        'hot_num_txt': '12.3万',
        'feed_comment_num': 456,
        'owner_star_average_score': '8.6',
        'owner_rating_total_num': 789,
        'product_specs': ['骁龙8 Elite', '6.36英寸'],
        'rating_item_info': [
          {'name': '性能', 'score': 9.1},
          {'name': '续航', 'score': 8.2},
        ],
        'tabList': [],
      });
      expect(detail.title, '小米15');
      expect(detail.logo, 'https://example.com/logo.png');
      expect(detail.description, '旗舰直屏');
      expect(detail.hotNumText, '12.3万');
      expect(detail.commentNumText, '456');
      expect(detail.score, 8.6);
      expect(detail.scoreCount, 789);
      expect(detail.specs, ['骁龙8 Elite', '6.36英寸']);
      expect(detail.ratingItems.length, 2);
      expect(detail.ratingItems[0].name, '性能');
      expect(detail.ratingItems[0].score, 9.1);
      expect(detail.tabs, isEmpty);
    });

    test('non-map detail throws', () {
      expect(() => parseProductDetail('123', ['not', 'a', 'map']),
          throwsFormatException);
    });
  });

  group('parseProductTabs', () {
    test('feed and sub-tab tabs are kept, others are dropped', () {
      final tabs = parseProductTabs('123', [
        {
          'title': '讨论',
          'url': '/page?url=/product/feedList&id=123&type=feed',
          'is_open': '1',
        },
        {
          'title': '样张',
          'url':
              '/page?url=/product/feedList&id=123&type=subTabFeed&subId=5',
          'is_open': '1',
        },
        {
          'title': '参数',
          'url': '/page?url=/product/feedList&id=123&type=main',
          'is_open': '1',
        },
        {
          'title': '评分',
          'url': '/page?url=/product/feedList&id=123&type=rating',
          'is_open': '1',
        },
        {
          'title': '别家产品',
          'url': '/page?url=/product/feedList&id=999&type=feed',
          'is_open': '1',
        },
        {
          'title': '已关闭',
          'url': '/page?url=/product/feedList&id=123&type=feed',
          'is_open': '0',
        },
        {
          'title': '外链',
          'url': '/some/external/page',
          'is_open': '1',
        },
        {
          'title': '讨论',
          'url': '/page?url=/product/feedList&id=123&type=feed',
          'is_open': '1',
        },
      ]);
      expect(tabs.length, 2);
      expect(tabs[0].label, '讨论');
      expect(tabs[0].feedType, 'feed');
      expect(tabs[1].label, '样张');
      expect(tabs[1].subId, '5');
    });

    test('non-list tabList yields no tabs', () {
      expect(parseProductTabs('123', null), isEmpty);
      expect(parseProductTabs('123', 'nonsense'), isEmpty);
    });
  });
}
