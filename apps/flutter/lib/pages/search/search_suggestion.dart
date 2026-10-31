/// Hot-search keywords and input suggestions for the global search page.
///
/// The endpoints come from the Coolapk v6 API, the same family the app
/// already uses for search results, and match what coolapk-desktop calls:
/// hot searches are `GET /v6/search?type=hotSearch&refresh=1&returnType=all`
/// and suggestions are `GET /v6/search/suggestSearchWordsNew?searchValue=...`
/// (with an extra `type=app` variant that is tried first, like the desktop
/// client does, falling back to the general variant when it is empty).
///
/// The parsers here are deliberately defensive: they walk the `data` payload
/// recursively instead of going through `NetworkRepo.handleListResponse`,
/// because suggestion/hot rows are not feed entities and must not be dropped
/// by the feed `entityTemplateList` filter. A row is classified only from
/// fields the payload itself carries (entityType, entityTemplate, uid, tag,
/// packageName, or a `searchtab://` action URL), so an unknown future row
/// degrades to a plain keyword search instead of disappearing.
enum SearchSuggestionKind { user, topic, app, product, keyword }

class SearchSuggestion {
  const SearchSuggestion({
    required this.kind,
    required this.title,
    required this.keyword,
    this.uid,
    this.tag,
    this.packageName,
    this.productId,
  });

  final SearchSuggestionKind kind;

  /// Raw row title, without any category prefix.
  final String title;

  /// Keyword to search with when the row has no direct destination.
  final String keyword;
  final String? uid;
  final String? tag;
  final String? packageName;
  final String? productId;

  /// Title as shown in the suggestion list. The user row for a generic
  /// keyword is shown as "搜索用户：<keyword>" (the official client's form);
  /// a row for a specific user just shows the username. Topic rows are
  /// shown with a leading '#'.
  String get displayTitle {
    switch (kind) {
      case SearchSuggestionKind.user:
        return uid == null ? '搜索用户：$title' : title;
      case SearchSuggestionKind.topic:
        final topic = (tag ?? title).replaceAll(RegExp(r'^#+'), '');
        return '#$topic';
      case SearchSuggestionKind.app:
      case SearchSuggestionKind.product:
      case SearchSuggestionKind.keyword:
        return title;
    }
  }
}

String _text(dynamic value) {
  if (value is String) return value.trim();
  if (value == null) return '';
  return value.toString().trim();
}

String _firstText(Map map, List<String> keys) {
  for (final key in keys) {
    final text = _text(map[key]);
    if (text.isNotEmpty) return text;
  }
  return '';
}

bool _isSponsor(Map map) {
  final type = _firstText(map, ['entityType', 'entity_type', 'type'])
      .toLowerCase();
  final template = _firstText(map, ['entityTemplate', 'entity_template', 'template'])
      .toLowerCase();
  if (type.startsWith('sponsor') || template.startsWith('sponsor')) {
    return true;
  }
  final sponsorType = map['sponsorType'] ?? map['sponsor_type'];
  if (sponsorType is bool) return sponsorType;
  if (sponsorType is num) return sponsorType != 0;
  return _text(sponsorType).isNotEmpty;
}

/// Collects the leaf entity maps of a search payload. Container maps that
/// only group other rows (a `listCard` with an `entities` list, or a
/// wrapper with a `data`/`list`/`items` list and no title of its own) are
/// flattened into their children; their own title is never emitted as a
/// keyword, so a "热门搜索" header can never become a suggestion.
void _collectLeafMaps(dynamic node, List<Map> out) {
  if (node is List) {
    for (final item in node) {
      _collectLeafMaps(item, out);
    }
    return;
  }
  if (node is! Map) return;
  final children = node['entities'] ?? node['entityList'];
  if (children is List) {
    for (final item in children) {
      _collectLeafMaps(item, out);
    }
    return;
  }
  const titleKeys = [
    'title',
    'name',
    'username',
    'searchValue',
    'label',
    'message_title',
    'messageTitle',
  ];
  if (_firstText(node, titleKeys).isEmpty) {
    for (final key in ['data', 'list', 'items']) {
      final child = node[key];
      if (child is List) {
        for (final item in child) {
          _collectLeafMaps(item, out);
        }
        return;
      }
    }
  }
  out.add(node);
}

SearchSuggestion? _toSuggestion(Map map) {
  if (_isSponsor(map)) return null;
  final title = _firstText(map, [
    'title',
    'name',
    'username',
    'searchValue',
    'label',
    'message_title',
    'messageTitle',
  ]);
  if (title.isEmpty) return null;
  final type = _firstText(map, ['entityType', 'entity_type', 'type'])
      .toLowerCase();
  final template = _firstText(map, ['entityTemplate', 'entity_template', 'template'])
      .toLowerCase();
  final url = _firstText(map, ['url', 'actionUrl', 'action_url', 'link']);

  // The desktop client resolves suggestion rows through a
  // `searchtab://<searchType>?keyword=<keyword>` action URL; honour it
  // the same way instead of guessing from the title.
  if (url.toLowerCase().startsWith('searchtab:')) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final searchType = uri.host.toLowerCase();
      final keyword = uri.queryParameters['keyword']?.trim() ?? '';
      final effectiveKeyword = keyword.isNotEmpty ? keyword : title;
      if (searchType.contains('user')) {
        return SearchSuggestion(
            kind: SearchSuggestionKind.user,
            title: effectiveKeyword,
            keyword: effectiveKeyword);
      }
      if (searchType.contains('topic') || searchType.contains('tag')) {
        return SearchSuggestion(
            kind: SearchSuggestionKind.topic,
            title: effectiveKeyword,
            keyword: effectiveKeyword,
            tag: effectiveKeyword);
      }
      if (searchType.contains('apk') || searchType.contains('app')) {
        return SearchSuggestion(
            kind: SearchSuggestionKind.app,
            title: effectiveKeyword,
            keyword: effectiveKeyword);
      }
      if (searchType.contains('product')) {
        return SearchSuggestion(
            kind: SearchSuggestionKind.product,
            title: effectiveKeyword,
            keyword: effectiveKeyword);
      }
      return SearchSuggestion(
          kind: SearchSuggestionKind.keyword,
          title: effectiveKeyword,
          keyword: effectiveKeyword);
    }
  }

  final uid = _firstText(map, ['uid', 'userId', 'user_id']);
  if (uid.isNotEmpty || type.contains('user')) {
    return SearchSuggestion(
        kind: SearchSuggestionKind.user,
        title: title,
        keyword: title,
        uid: uid.isEmpty ? null : uid);
  }
  final tag = _firstText(map, ['tag', 'topicTag', 'topic_tag', 'topicName']);
  if (tag.isNotEmpty ||
      type.contains('topic') ||
      type.contains('tag') ||
      template.contains('topic') ||
      url.contains('/topic/') ||
      url.contains('/t/')) {
    return SearchSuggestion(
        kind: SearchSuggestionKind.topic,
        title: title,
        keyword: title,
        tag: tag.isEmpty ? title.replaceAll(RegExp(r'^#+'), '') : tag);
  }
  final packageName = _firstText(
      map, ['packageName', 'package_name', 'pkg', 'apkname', 'apkName']);
  if (packageName.isNotEmpty || type.contains('apk')) {
    return SearchSuggestion(
        kind: SearchSuggestionKind.app,
        title: title,
        keyword: title,
        packageName: packageName.isEmpty ? null : packageName);
  }
  if (type.contains('product')) {
    final productId = _firstText(map, ['id', 'entityId', 'entity_id']);
    return SearchSuggestion(
        kind: SearchSuggestionKind.product,
        title: title,
        keyword: title,
        productId: productId.isEmpty ? null : productId);
  }
  return SearchSuggestion(
      kind: SearchSuggestionKind.keyword, title: title, keyword: title);
}

/// Parses a `suggestSearchWordsNew` payload into classified suggestion
/// rows, in payload order, deduplicated. Unknown rows become keyword rows.
List<SearchSuggestion> parseSearchSuggestions(dynamic data) {
  final leaves = <Map>[];
  _collectLeafMaps(data, leaves);
  final rows = <SearchSuggestion>[];
  final seen = <String>{};
  for (final leaf in leaves) {
    final suggestion = _toSuggestion(leaf);
    if (suggestion == null) continue;
    final key =
        '${suggestion.kind.name}:${suggestion.displayTitle}:${suggestion.keyword}';
    if (seen.add(key)) rows.add(suggestion);
  }
  return rows;
}

/// Parses a `type=hotSearch` payload into plain keywords, in payload
/// order, deduplicated. A payload that is already a list of strings is
/// accepted as-is.
List<String> parseHotSearchKeywords(dynamic data) {
  if (data is List) {
    final keywords = <String>[];
    for (final item in data) {
      if (item is String) {
        final text = item.trim();
        if (text.isNotEmpty && !keywords.contains(text)) {
          keywords.add(text);
        }
      }
    }
    if (keywords.isNotEmpty) return keywords;
  }
  final leaves = <Map>[];
  _collectLeafMaps(data, leaves);
  final keywords = <String>[];
  for (final leaf in leaves) {
    if (_isSponsor(leaf)) continue;
    final title = _firstText(leaf, [
      'title',
      'name',
      'username',
      'searchValue',
      'label',
    ]);
    if (title.isEmpty || title == '热门搜索') continue;
    if (!keywords.contains(title)) keywords.add(title);
  }
  return keywords;
}
