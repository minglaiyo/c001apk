import 'dart:convert';

import 'datum.dart';

/// 动态卡片上的一条价格行：是什么、金额、所属配置。
/// 移植自 Costben `model/FeedPrice.kt`（AGPL-3.0），适配 Dart 与酷安字段口径。
class FeedPrice {
  const FeedPrice(this.label, this.amount, this.configuration);
  final String label;
  final String amount;
  final String? configuration;
}

/// 二手/交易动态指向的外部 listing。
class TradeLink {
  const TradeLink(this.label, this.url, this.isXianyu);
  final String label;
  final String url;
  final bool isXianyu;
}

final _amountPattern = RegExp(r'[0-9]{1,12}(\.[0-9]{1,2})?');

/// 缺失、为零和格式异常的金额一律隐藏，而不是读成“免费”或“议价”：
/// 同一份列表里字段会以数字、字符串和空字符串出现。
String? _asPrice(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  final match = _amountPattern.firstMatch(value);
  if (match == null || match.group(0) != value) return null;
  final parsed = num.tryParse(value);
  if (parsed == null || parsed <= 0) return null;
  var text = parsed.toString();
  if (text.contains('.')) {
    text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return '¥$text';
}

/// `tsubdata`、`ershou_info` 与 `extraData` 可能是对象，也可能是 JSON 字符串。
Map<String, dynamic>? _embedded(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

String? _string(Map<String, dynamic>? map, String key) {
  final value = map?[key]?.toString();
  return value == null || value.isEmpty ? null : value;
}

/// 动态卡片展示的价格。`tsubid` 6 表示通过到手价页签读取的动态，价格在
/// `tsubdata`；二手与交易动态的价格在 `ershou_info`。
FeedPrice? priceDisplay(Map<String, dynamic> data) {
  if (data['tsubid']?.toString() == '6') {
    final purchase = _embedded(data['tsubdata']);
    final amount = _asPrice(purchase?['final_price'] ?? purchase?['price']);
    if (purchase != null && amount != null) {
      return FeedPrice('到手价', amount, _string(purchase, 'config_name'));
    }
  }
  if (const {'ershou', 'trade'}.contains(data['feedType']?.toString())) {
    final info = _embedded(data['ershou_info']);
    if (info == null) return null;
    final amount = _asPrice(info['product_price']);
    if (amount != null) {
      final config = _embedded(info['product_config_data']);
      var name = _string(config, 'configTitle') ?? '';
      if (name.isEmpty) {
        name = [
          _string(config, 'ram') ?? '',
          _string(config, 'rom') ?? ''
        ].where((part) => part.isNotEmpty).join('+');
      }
      return FeedPrice('交易价', amount, name.isEmpty ? null : name);
    }
  }
  return null;
}

/// 二手动态携带可用外链时的 listing。
TradeLink? tradeLink(Map<String, dynamic> data) {
  if (!const {'ershou', 'trade'}.contains(data['feedType']?.toString())) {
    return null;
  }
  final info = _embedded(data['ershou_info']);
  if (info == null) return null;
  final url = (info['link_url']?.toString() ?? '').trim();
  if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
  return info['link_source']?.toString() == '闲鱼'
      ? TradeLink('查看闲鱼', url, true)
      : TradeLink('查看交易链接', url, false);
}

/// `subTabFeedCard6` 行：子页签的参考价（非均值、非保证），
/// 标明价格来源的动态以便卡片可以打开它。
FeedPrice? purchasePriceSummary(Map<String, dynamic> data) {
  if (data['entityTemplate']?.toString() != 'subTabFeedCard6') return null;
  final extra = _embedded(data['extraData']);
  if (extra == null) return null;
  final amount = _asPrice(extra['final_price']);
  return amount == null ? null : FeedPrice('到手价参考', amount, null);
}

/// 参考价来源的动态 id，行里没有给出时为空。
String purchasePriceSummaryFeedId(Map<String, dynamic> data) {
  final extra = _embedded(data['extraData']);
  final id = extra?['feed_id']?.toString() ?? '';
  final parsed = int.tryParse(id);
  return parsed != null && parsed > 0 ? id : '';
}

/// 参考价最近一次读取时间。
String purchasePriceSummaryUpdateTime(Map<String, dynamic> data) {
  return _embedded(data['extraData'])?['update_time']?.toString() ?? '';
}

/// Datum 到价格载荷视图的适配：字段子集拼成 priceDisplay/tradeLink 需要的形状。
extension FeedPriceDatum on Datum {
  Map<String, dynamic> get priceData => {
        'tsubid': tsubid,
        'tsubdata': tsubdata,
        'ershou_info': ershouInfo,
        'feedType': feedType,
        'entityTemplate': entityTemplate,
        'extraData': extraData,
      };

  /// 卡片价格行（到手价/交易价），无价格时为 null。
  FeedPrice? get priceDisplayOf => priceDisplay(priceData);

  /// 二手/交易外链，无可用链接时为 null。
  TradeLink? get tradeLinkOf => tradeLink(priceData);

  /// 「仅自己可见」：publishStatus 2。
  bool get isSelfOnly => publishStatus?.toString() == '2';
}
