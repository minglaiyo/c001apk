import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/cards/search_history_card.dart';
import '../../pages/search/search_page_controller.dart';
import '../../pages/search/search_suggestion.dart';
import '../../utils/extensions.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final String? _title = Get.parameters['title'];
  final String? _pageType = Get.parameters['pageType'];
  final String? _pageParam = Get.parameters['pageParam'];
  final _clearStream = StreamController<bool>();

  late final _searchPageController =
      Get.put(SearchPageController(), tag: '$_title$_pageType$_pageParam');

  /// True for a scoped search (in a title, a user, a topic, ...): hot
  /// searches and input suggestions are a global-search feature only,
  /// like coolapk-desktop's scoped-search guard.
  bool get _isScoped =>
      !_title.isNullOrEmpty ||
      !_pageType.isNullOrEmpty ||
      !_pageParam.isNullOrEmpty;

  String _query = '';

  @override
  void initState() {
    super.initState();
    if (!_isScoped) _searchPageController.loadHotSearches();
  }

  @override
  void dispose() {
    _clearStream.close();
    _controller.dispose();
    _focusNode.dispose();
    Get.delete<SearchPageController>(tag: '$_title$_pageType$_pageParam');
    super.dispose();
  }

  void onSearch(String text, {String? contentType}) async {
    if (text.isNotEmpty) {
      _searchPageController.handleSearch(text);
      await Get.toNamed('/searchResult', parameters: {
        'keyword': text,
        if (!_title.isNullOrEmpty) 'title': _title!,
        if (!_pageType.isNullOrEmpty) 'pageType': _pageType!,
        if (!_pageParam.isNullOrEmpty) 'pageParam': _pageParam!,
        if (contentType != null && _isScoped == false)
          'contentType': contentType,
      });
      _focusNode.requestFocus();
    }
  }

  void onSuggestionTap(SearchSuggestion suggestion) {
    switch (suggestion.kind) {
      case SearchSuggestionKind.user:
        if (suggestion.uid != null) {
          Get.toNamed('/u/${suggestion.uid}');
          return;
        }
        _controller.text = suggestion.keyword;
        _clearStream.add(true);
        onSearch(suggestion.keyword, contentType: 'user');
      case SearchSuggestionKind.topic:
        if (suggestion.tag != null) {
          Get.toNamed('/t/${suggestion.tag}');
          return;
        }
        _controller.text = suggestion.keyword;
        _clearStream.add(true);
        onSearch(suggestion.keyword, contentType: 'topic');
      case SearchSuggestionKind.app:
        if (suggestion.packageName != null) {
          Get.toNamed('/apk/${suggestion.packageName}');
          return;
        }
        _controller.text = suggestion.keyword;
        _clearStream.add(true);
        onSearch(suggestion.keyword, contentType: 'app');
      case SearchSuggestionKind.product:
        _controller.text = suggestion.keyword;
        _clearStream.add(true);
        onSearch(suggestion.keyword, contentType: 'product');
      case SearchSuggestionKind.keyword:
        _controller.text = suggestion.keyword;
        _clearStream.add(true);
        onSearch(suggestion.keyword);
    }
  }

  IconData _suggestionIcon(SearchSuggestionKind kind) {
    switch (kind) {
      case SearchSuggestionKind.user:
        return Icons.person;
      case SearchSuggestionKind.topic:
        return Icons.tag;
      case SearchSuggestionKind.app:
        return Icons.apps;
      case SearchSuggestionKind.product:
        return Icons.smartphone;
      case SearchSuggestionKind.keyword:
        return Icons.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          focusNode: _focusNode,
          onTap: () => _focusNode.requestFocus(),
          controller: _controller,
          style: const TextStyle(fontSize: 18),
          onChanged: (value) {
            _clearStream.add(value.isNotEmpty);
            setState(() => _query = value);
            if (!_isScoped) _searchPageController.onQueryChanged(value);
          },
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: !_title.isNullOrEmpty ? '在 $_title 中搜索' : '搜索',
            hintStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
            ),
          ),
          textInputAction: TextInputAction.search,
          autofocus: true,
          onSubmitted: (value) {
            onSearch(value);
          },
        ),
        actions: [
          StreamBuilder(
            initialData: false,
            stream: _clearStream.stream,
            builder: (_, snapshot) => snapshot.data == true
                ? IconButton(
                    onPressed: () {
                      _controller.clear();
                      _focusNode.requestFocus();
                      _clearStream.add(false);
                      setState(() => _query = '');
                      if (!_isScoped) _searchPageController.onQueryChanged('');
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: '清除',
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            onPressed: () {
              onSearch(_controller.text);
            },
            icon: const Icon(Icons.search),
            tooltip: '搜索',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.zero,
          child: Divider(height: 1),
        ),
      ),
      body: Obx(() {
        // Typing in global search: show the live suggestion list (or
        // nothing while it loads / returns nothing), never the
        // hot/history sections underneath it.
        if (_query.trim().isNotEmpty && !_isScoped) {
          final suggestions = _searchPageController.suggestionList;
          if (suggestions.isEmpty) return const SizedBox();
          return ListView.builder(
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return ListTile(
                leading: Icon(_suggestionIcon(suggestion.kind)),
                title: Text(
                  suggestion.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSuggestionTap(suggestion),
              );
            },
          );
        }
        // Empty query: search history above hot searches (global only).
        final hotList = _searchPageController.hotList;
        final historyList = _searchPageController.historyList;
        if (hotList.isEmpty && historyList.isEmpty) {
          return const SizedBox();
        }
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: 10 + MediaQuery.of(context).padding.bottom,
          ),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (historyList.isNotEmpty) ...[
                Row(
                  children: [
                    const SizedBox(width: 10),
                    const Expanded(
                      flex: 1,
                      child: Text(
                        '搜索历史',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '清除全部',
                      onPressed: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: const Text('确定清除全部搜索历史？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Get.back();
                                      _searchPageController.clearAll();
                                    },
                                    child: const Text('确定'),
                                  )
                                ],
                              )),
                      icon: const Icon(Icons.clear_all),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: historyList
                        .map(
                          (text) => SearchHistoryCard(
                            text: text,
                            onTap: () {
                              _controller.text = text;
                              _clearStream.add(true);
                              onSearch(text);
                            },
                            onLongPress: () =>
                                _searchPageController.handleSearch(text, true),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (hotList.isNotEmpty) ...[
                const Row(
                  children: [
                    SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '热门搜索',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: hotList
                        .map(
                          (text) => SearchHistoryCard(
                            text: text,
                            onTap: () {
                              _controller.text = text;
                              _clearStream.add(true);
                              setState(() => _query = text);
                              onSearch(text);
                            },
                            onLongPress: () {},
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
