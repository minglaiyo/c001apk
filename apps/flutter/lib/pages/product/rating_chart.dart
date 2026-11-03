/// 评分分布的宽容解析。
///
/// 未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码：
/// GET /v6/product/ratingChart?id=…。返回结构未经实测，所以这里只认
/// 总体星级分布（1–5 星人数），分项人数不硬编：若返回里没有可识别
/// 的总体分布，[RatingChartData.recognized] 为 false，明细页只写
/// “总体分布暂未返回”，原有平均分明细不受影响。
class RatingChartData {
  const RatingChartData({
    required this.recognized,
    this.starCounts = const {},
    this.total,
  });

  final bool recognized;

  /// 星级（1–5）→ 人数。
  final Map<int, int> starCounts;
  final int? total;
}

int? _toInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) {
    // 人数可能是 "1,234"、"45%"、"45.6" 这类文本，直接 int.tryParse 会失败。
    final cleaned = value.trim().replaceAll(',', '').replaceAll('%', '');
    final parsed = int.tryParse(cleaned) ?? double.tryParse(cleaned)?.toInt();
    return parsed;
  }
  return null;
}

String _text(dynamic value) => value == null ? '' : value.toString().trim();

/// 总体分布容器的键名：只沿着这些键往下找，不把任意嵌套结构
/// （例如各分项自己的分布）误当成总体分布。
const _distributionKeys = [
  'rating_chart',
  'chart',
  'distribution',
  'star_distribution',
  'score_distribution',
  'ratingDistribution',
  'starCounts',
  'stars',
  'ratings',
  'total_distribution',
  'chart_data',
  'data',
];

RatingChartData parseRatingChart(dynamic raw) {
  if (raw is List) {
    // 分布直接就是列表。
    return _fromList(raw);
  }
  if (raw is! Map) {
    return const RatingChartData(recognized: false);
  }
  // 本层直接就是星级键到人数的映射时先认。
  final direct = _fromMap(raw);
  if (direct.recognized) return direct;
  // 再沿分布键名往下找，最多 3 层（例如 data -> chart -> [...]）。
  final found = _findDistribution(raw, 0);
  if (found != null) return found;
  return const RatingChartData(recognized: false);
}

RatingChartData? _findDistribution(dynamic node, int depth) {
  if (depth > 3 || node is! Map) return null;
  for (final key in _distributionKeys) {
    final value = node[key];
    if (value is List && value.isNotEmpty) {
      final parsed = _fromList(value);
      if (parsed.recognized) return parsed;
    }
    if (value is Map && value.isNotEmpty) {
      final parsed = _fromMap(value);
      if (parsed.recognized) return parsed;
      final deeper = _findDistribution(value, depth + 1);
      if (deeper != null) return deeper;
    }
  }
  return null;
}

RatingChartData _fromList(List list) {
  final counts = <int, int>{};
  for (final item in list) {
    if (item is! Map) continue;
    final star = _toInt(item['star'] ?? item['score'] ?? item['level']);
    final count = _toInt(item['count'] ?? item['num'] ?? item['votes']);
    if (star != null && star >= 1 && star <= 5 && count != null) {
      counts[star] = count;
    }
  }
  if (counts.isEmpty) return const RatingChartData(recognized: false);
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  return RatingChartData(recognized: true, starCounts: counts, total: total);
}

RatingChartData _fromMap(Map map) {
  final counts = <int, int>{};
  for (final entry in map.entries) {
    final star = _toInt(entry.key);
    if (star == null || star < 1 || star > 5) continue;
    final count = entry.value is Map
        ? _toInt((entry.value as Map)['count'] ??
            (entry.value as Map)['num'] ??
            (entry.value as Map)['percent'])
        : _toInt(entry.value);
    if (count != null) counts[star] = count;
  }
  if (counts.isNotEmpty) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return RatingChartData(recognized: true, starCounts: counts, total: total);
  }
  // 形如 star1/star2… 或 one_star 等键的兜底。
  for (final entry in map.entries) {
    final key = _text(entry.key);
    final match = RegExp(r'([1-5])').firstMatch(key);
    if (match == null) continue;
    if (!key.contains('star') && !key.contains('score')) continue;
    final count = _toInt(entry.value);
    if (count != null) {
      counts[int.parse(match.group(1)!)] = count;
    }
  }
  if (counts.isEmpty) return const RatingChartData(recognized: false);
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  return RatingChartData(recognized: true, starCounts: counts, total: total);
}

/// 热度数值的宽容解析：Datum.hotNumTxt 常是“1.2万”这类文本，
/// Entity.hotNum 可能是数字或文本；都解析不到时返回 null。
double? parseHotCount(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = _text(value);
  if (text.isEmpty) return null;
  final match = RegExp(r'([\d.]+)\s*(万|亿|w|k)?', caseSensitive: false)
      .firstMatch(text);
  if (match == null) return null;
  final base = double.tryParse(match.group(1)!);
  if (base == null) return null;
  final unit = match.group(2)?.toLowerCase();
  if (unit == '万' || unit == 'w') return base * 10000;
  if (unit == '亿') return base * 100000000;
  if (unit == 'k') return base * 1000;
  return base;
}
