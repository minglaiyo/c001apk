/// Feed edit history, from `GET /v6/feed/changeHistoryList?id=...`,
/// the same endpoint coolapk-desktop's feed card uses for its
/// "编辑记录" dialog.
///
/// The list is returned current-first: the first item with
/// `isHistory == 0` is the current version, the rest are older
/// versions in reverse chronological order. Content is plain text for
/// display: any HTML markup in a version's message is stripped here,
/// because the history view is a plain-text list, not a rich-text feed
/// body. The change badge is a character-count summary against the
/// next older version (desktop shows a character diff; this view shows
/// full text per version, so the badge only summarises how much
/// changed, it does not highlight individual characters).
class FeedChangeHistoryItem {
  const FeedChangeHistoryItem({
    required this.isCurrent,
    required this.changeCount,
    this.timeMillis,
    required this.title,
    required this.content,
    required this.images,
  });

  /// True for the current version (first item, `isHistory == 0`).
  final bool isCurrent;

  /// Edit number from the payload, 0 when absent (the original).
  final int changeCount;
  final int? timeMillis;
  final String title;
  final String content;
  final List<String> images;

  String get versionLabel {
    if (isCurrent) return '当前版本';
    if (changeCount > 0) return '第 $changeCount 次编辑';
    return '原始版本';
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

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}

String _stripHtml(String text) {
  return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

int? _parseTime(Map map) {
  final raw = map['last_change_time'] ??
      map['lastChangeTime'] ??
      map['date'] ??
      map['dateline'] ??
      map['createTime'] ??
      map['create_time'];
  if (raw is num) {
    final value = raw.toInt();
    return value > 9999999999 ? value : value * 1000;
  }
  final parsed = int.tryParse(_text(raw));
  if (parsed == null) return null;
  return parsed > 9999999999 ? parsed : parsed * 1000;
}

/// Parses a `changeHistoryList` payload. Non-list payloads yield an
/// empty list, which the dialog shows as "暂无编辑记录".
List<FeedChangeHistoryItem> parseFeedChangeHistory(dynamic data) {
  if (data is! List) return [];
  final items = <FeedChangeHistoryItem>[];
  for (var index = 0; index < data.length; index++) {
    final raw = data[index];
    if (raw is! Map) continue;
    final isHistory = raw['isHistory'] ?? raw['is_history'];
    final isCurrent = index == 0 &&
        (isHistory == null ||
            isHistory == 0 ||
            isHistory == '0' ||
            isHistory == false);
    final images = <String>[];
    final rawImages = raw['picArr'];
    if (rawImages is List) {
      for (final image in rawImages) {
        final text = _text(image);
        if (text.isNotEmpty) images.add(text);
      }
    }
    final content = _stripHtml(_firstText(raw, [
      'message',
      'content',
      'text',
      'change_content',
      'description',
    ]));
    items.add(FeedChangeHistoryItem(
      isCurrent: isCurrent,
      changeCount: _toInt(raw['change_count'] ?? raw['changeCount']),
      timeMillis: _parseTime(raw),
      title: _firstText(raw, ['message_title', 'title']),
      content: content.isNotEmpty ? content : '（无详细内容）',
      images: images,
    ));
  }
  return items;
}

/// Change badge for [item] against the next older version [older], or
/// null for the oldest version (nothing to compare against).
String? feedChangeBadge(
    FeedChangeHistoryItem item, FeedChangeHistoryItem? older) {
  if (older == null) return null;
  if (item.content == older.content) return '文本无改动';
  final added = item.content.length - older.content.length;
  if (added > 0) return '+$added字';
  if (added < 0) return '${added}字';
  return '文本有改动';
}
