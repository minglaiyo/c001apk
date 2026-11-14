import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/logic/model/feed/feed_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('priceDisplay', () {
    test('到手价读取 tsubdata.final_price 与 config_name', () {
      final price = priceDisplay({
        'tsubid': '6',
        'tsubdata': {'final_price': '2999.00', 'config_name': '12+256GB'},
      });
      expect(price?.label, '到手价');
      expect(price?.amount, '¥2999');
      expect(price?.configuration, '12+256GB');
    });

    test('tsubdata 为 JSON 字符串时同样解析', () {
      final price = priceDisplay({
        'tsubid': '6',
        'tsubdata': '{"final_price":"199","config_name":"8+128GB"}',
      });
      expect(price?.amount, '¥199');
      expect(price?.configuration, '8+128GB');
    });

    test('二手价读取 ershou_info 并用 ram+rom 拼配置', () {
      final price = priceDisplay({
        'feedType': 'ershou',
        'ershou_info': {
          'product_price': '1500',
          'product_config_data': {'ram': '8GB', 'rom': '256GB'},
        },
      });
      expect(price?.label, '交易价');
      expect(price?.amount, '¥1500');
      expect(price?.configuration, '8GB+256GB');
    });

    test('缺失、为零与非法金额一律隐藏，不读成免费', () {
      expect(priceDisplay({'tsubid': '6', 'tsubdata': {'final_price': '0'}}),
          isNull);
      expect(priceDisplay({'tsubid': '6', 'tsubdata': {'final_price': ''}}),
          isNull);
      expect(priceDisplay({'tsubid': '6', 'tsubdata': {'final_price': 'abc'}}),
          isNull);
      expect(priceDisplay({'feedType': 'ershou', 'ershou_info': {}}), isNull);
      expect(priceDisplay({}), isNull);
    });

    test('小数金额去掉尾随零', () {
      expect(
          priceDisplay({
            'feedType': 'trade',
            'ershou_info': {'product_price': '99.50'},
          })?.amount,
          '¥99.5');
    });
  });

  group('tradeLink', () {
    test('闲鱼来源标记 isXianyu 并使用对应文案', () {
      final link = tradeLink({
        'feedType': 'ershou',
        'ershou_info': {'link_url': 'https://2.taobao.com/x', 'link_source': '闲鱼'},
      });
      expect(link?.label, '查看闲鱼');
      expect(link?.isXianyu, isTrue);
    });

    test('非 http(s) 链接与其它来源的处理', () {
      expect(
          tradeLink({
            'feedType': 'ershou',
            'ershou_info': {'link_url': 'ftp://x'},
          }),
          isNull);
      final other = tradeLink({
        'feedType': 'trade',
        'ershou_info': {'link_url': 'https://example.com/x'},
      });
      expect(other?.label, '查看交易链接');
      expect(other?.isXianyu, isFalse);
    });
  });

  group('仅自己可见', () {
    test('publishStatus 2 判定为仅自己可见，其它值不判定', () {
      expect(Datum(entityType: 'feed', publishStatus: '2').isSelfOnly, isTrue);
      expect(Datum(entityType: 'feed', publishStatus: 2).isSelfOnly, isTrue);
      expect(Datum(entityType: 'feed', publishStatus: '1').isSelfOnly, isFalse);
      expect(Datum(entityType: 'feed').isSelfOnly, isFalse);
    });
  });
}
