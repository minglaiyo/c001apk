import 'dart:async';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../logic/network/network_repo.dart';
import '../../pages/search/search_suggestion.dart';
import '../../utils/storage_util.dart';

class SearchPageController extends GetxController {
  Box searchHistory = GStorage.searchHistory;
  RxList historyList = [].obs;

  /// Hot-search keywords for the empty global search page. Loaded once,
  /// only by the page itself when it is not a scoped (in-title/in-user/
  /// in-topic) search.
  RxList<String> hotList = <String>[].obs;

  /// Classified input suggestions for the current query, at most 8 rows.
  /// Empty while the query is empty, while a lookup is in flight, or
  /// when the lookup returned nothing.
  RxList<SearchSuggestion> suggestionList = <SearchSuggestion>[].obs;

  Timer? _suggestDebounce;
  int _suggestionSequence = 0;
  bool _hotLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _getData();
  }

  @override
  void onClose() {
    _suggestDebounce?.cancel();
    super.onClose();
  }

  Future<void> _getData() async {
    historyList.value = searchHistory.get('searchHistory') ?? [];
  }

  Future<void> loadHotSearches() async {
    if (_hotLoaded) return;
    _hotLoaded = true;
    hotList.value = await NetworkRepo.getHotSearches();
  }

  /// Called on every query change by the page (global search only).
  /// Debounced 300ms like coolapk-desktop, and guarded by a sequence
  /// number so a slow earlier response never overwrites a newer query's
  /// results. The `app` suggestion variant is tried first; when it is
  /// empty, the general variant is used.
  void onQueryChanged(String value) {
    _suggestDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      suggestionList.clear();
      return;
    }
    final sequence = ++_suggestionSequence;
    _suggestDebounce =
        Timer(const Duration(milliseconds: 300), () async {
      var rows = await NetworkRepo.getSearchSuggestions(trimmed, app: true);
      if (sequence != _suggestionSequence) return;
      if (rows.isEmpty) {
        rows = await NetworkRepo.getSearchSuggestions(trimmed);
        if (sequence != _suggestionSequence) return;
      }
      suggestionList.value = rows.take(8).toList();
    });
  }

  void handleSearch(String value, [bool isDelete = false]) {
    List list = historyList.where((data) => data != value).toList();
    if (!isDelete) {
      list.insert(0, value);
    }
    historyList.value = list;
    searchHistory.put('searchHistory', list);
  }

  void clearAll() {
    historyList.value = [];
    searchHistory.put('searchHistory', []);
  }
}
