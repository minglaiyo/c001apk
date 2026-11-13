import 'package:c001apk_flutter/pages/search/search_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseHotSearchKeywords', () {
    test('plain string list is returned deduplicated', () {
      expect(
        parseHotSearchKeywords(['小米note', '双11开箱', '小米note']),
        ['小米note', '双11开箱'],
      );
    });

    test('container entities are flattened and headers are not keywords',
        () {
      final data = [
        {
          'entityTemplate': 'searchHotCard',
          'title': '热门搜索',
          'entities': [
            {'title': '新手指南'},
            {'title': '新机资讯'},
          ],
        },
      ];
      expect(parseHotSearchKeywords(data), ['新手指南', '新机资讯']);
    });

    test('sponsor rows are skipped', () {
      final data = [
        {'title': '正常词'},
        {'entityType': 'sponsor', 'title': '推广词'},
      ];
      expect(parseHotSearchKeywords(data), ['正常词']);
    });
  });

  group('parseSearchSuggestions', () {
    test('generic user row, topic row and keyword row are classified',
        () {
      final data = [
        {'entityType': 'searchUser', 'title': '小米note'},
        {'entityType': 'searchTopic', 'title': '小米Note', 'tag': '小米Note'},
        {'title': '小米Note2'},
      ];
      final rows = parseSearchSuggestions(data);
      expect(rows.length, 3);
      expect(rows[0].kind, SearchSuggestionKind.user);
      expect(rows[0].displayTitle, '搜索用户：小米note');
      expect(rows[1].kind, SearchSuggestionKind.topic);
      expect(rows[1].displayTitle, '#小米Note');
      expect(rows[1].tag, '小米Note');
      expect(rows[2].kind, SearchSuggestionKind.keyword);
      expect(rows[2].displayTitle, '小米Note2');
    });

    test('specific user and app rows keep their destinations', () {
      final data = [
        {'entityType': 'user', 'username': '某数码博主', 'uid': 12345},
        {
          'entityType': 'apk',
          'title': '酷安',
          'packageName': 'com.coolapk.market'
        },
      ];
      final rows = parseSearchSuggestions(data);
      expect(rows[0].kind, SearchSuggestionKind.user);
      expect(rows[0].displayTitle, '某数码博主');
      expect(rows[0].uid, '12345');
      expect(rows[1].kind, SearchSuggestionKind.app);
      expect(rows[1].packageName, 'com.coolapk.market');
    });

    test('searchtab action urls resolve their search type', () {
      final data = [
        {
          'title': '小米note',
          'url': 'searchtab://user?keyword=小米note',
        },
        {
          'title': '小米Note3',
          'url': 'searchtab://topic?keyword=小米Note3',
        },
      ];
      final rows = parseSearchSuggestions(data);
      expect(rows[0].kind, SearchSuggestionKind.user);
      expect(rows[1].kind, SearchSuggestionKind.topic);
      expect(rows[1].tag, '小米Note3');
    });

    test('containers are flattened and duplicates are removed', () {
      final data = [
        {
          'entityTemplate': 'listCard',
          'entities': [
            {'title': '小米note'},
            {'title': '小米note'},
          ],
        },
      ];
      final rows = parseSearchSuggestions(data);
      expect(rows.length, 1);
      expect(rows[0].keyword, '小米note');
    });
  });
}
