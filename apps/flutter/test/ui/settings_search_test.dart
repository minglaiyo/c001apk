import 'package:c001apk_flutter/pages/settings/settings_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty query returns the whole settings index', () {
    expect(searchSettings(''), settingsSearchEntries);
    expect(searchSettings('   '), settingsSearchEntries);
  });

  test('title and keyword matches', () {
    final backToTop = searchSettings('回顶键');
    expect(backToTop.map((entry) => entry.itemId),
        containsAll(['backToTop', 'backToTopSide']));

    final cache = searchSettings('缓存');
    expect(cache.map((entry) => entry.itemId),
        containsAll(['autoCacheCleanup', 'clearCache']));
  });

  test('every token must match', () {
    expect(searchSettings('回顶键 左侧').map((entry) => entry.itemId),
        ['backToTopSide']);
    expect(searchSettings('回顶键 不存在'), isEmpty);
  });

  test('section titles are searchable', () {
    final storage =
        searchSettings('存储').map((entry) => entry.itemId).toList();
    expect(storage, contains('autoCacheCleanup'));
    expect(storage, contains('clearCache'));
  });
}
