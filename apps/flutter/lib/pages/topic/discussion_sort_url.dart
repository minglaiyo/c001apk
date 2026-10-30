import 'topic_page.dart' show TopicSortType;

/// 讨论 tab 排序的 URL 拼装，对齐 c001apk_next 的 ProductSortHeaderAdapter。
///
/// 两类讨论走不同的服务端参数，URL 格式也不同，所以分开处理：
///
/// * 产品讨论：`product/feedList`，走 `listType`（默认不带 listType，
///   最新 `dateline_desc`，热度 `rank_score`）。
/// * 话题讨论：`topic/tagFeedList` 且带 `withSortCard=1`，走 `sortField`
///   （默认 `lastupdate_desc`，最新 `dateline_desc`，热度 `rank_score`）。
///
/// 产品页 / 话题页下发的 tab URL 可能是 URL 编码的（如
/// `%2Ftopic%2FtagFeedList`），判断和拼装前必须先解码，否则
/// contains 匹配不到，排序条就不会出现。
String _decode(String url) {
  try {
    return Uri.decodeFull(url);
  } catch (_) {
    return url;
  }
}

/// 是否为带排序卡片的话题讨论 tab。
bool isTopicDiscussionUrl(String url) {
  final decoded = _decode(url);
  return decoded.contains('topic/tagFeedList') &&
      decoded.contains('withSortCard=1');
}

String _topicSortValue(TopicSortType type) => switch (type) {
      TopicSortType.DEFAULT => 'lastupdate_desc',
      TopicSortType.DATELINE => 'dateline_desc',
      TopicSortType.HOT => 'rank_score',
    };

/// 话题讨论：给当前 URL 换上对应排序的 sortField。
///
/// 已有 sortField 就替换，没有就追加；对已拼过一次的 URL 再拼一次
/// 结果不变（幂等），所以监听里每次都可以用当前 URL 直接算。
String topicDiscussionSortUrl(String currentUrl, TopicSortType type) {
  final decoded = _decode(currentUrl);
  final sortValue = _topicSortValue(type);
  if (decoded.contains('sortField=')) {
    return decoded.replaceAll(
      RegExp(r'sortField=[^&]*'),
      'sortField=$sortValue',
    );
  }
  final separator = decoded.contains('?') ? '&' : '?';
  return '$decoded${separator}sortField=$sortValue';
}

/// 产品讨论：按排序拼出新的 feedList URL。
///
/// 与 TopicContent 原有逻辑逐字一致：默认和最新带
/// `ignoreEntityById=1`，热度不带。
String productDiscussionSortUrl(String id, TopicSortType type) {
  const base = '/page?url=/product/feedList?type=feed&id=';
  switch (type) {
    case TopicSortType.DEFAULT:
      return '${base}$id&ignoreEntityById=1';
    case TopicSortType.DATELINE:
      return '${base}$id&ignoreEntityById=1&listType=dateline_desc';
    case TopicSortType.HOT:
      return '${base}$id&listType=rank_score';
  }
}

/// 排序条上显示的短标签（与原有产品逻辑一致）。
String discussionSortLabel(TopicSortType type) => switch (type) {
      TopicSortType.DEFAULT => '默认',
      TopicSortType.DATELINE => '最新',
      TopicSortType.HOT => '热度',
    };
