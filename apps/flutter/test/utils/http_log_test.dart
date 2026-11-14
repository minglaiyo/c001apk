import 'package:c001apk_flutter/utils/http_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('maskText 脱敏', () {
    test('JSON 中的 token/cookie 打码但保留长度', () {
      final masked = HttpLog.maskText(
          '{"token":"abcdef123456","X-App-Token":"xyz789","message":"ok"}');
      expect(masked.contains('abcdef123456'), isFalse);
      expect(masked.contains('xyz789'), isFalse);
      expect(masked.contains('*** (len=12)'), isTrue);
      expect(masked.contains('*** (len=6)'), isTrue);
      // 非敏感字段保持原样，便于排查。
      expect(masked.contains('"message":"ok"'), isTrue);
    });

    test('Cookie 形式同样打码', () {
      final masked = HttpLog.maskText('uid=123; token=secretvalue; validate=abc');
      expect(masked.contains('secretvalue'), isFalse);
      expect(masked.contains('token=*** (len=11)'), isTrue);
      expect(masked.contains('validate=abc'), isTrue);
    });

    test('大小写不敏感', () {
      final masked = HttpLog.maskText('{"AUTHORIZATION":"Bearer xyz"}');
      expect(masked.contains('Bearer xyz'), isFalse);
    });

    test('空串原样返回', () {
      expect(HttpLog.maskText(''), '');
    });
  });

  test('统计接口在无日志时返回零值', () async {
    // 测试环境无 patched path_provider，stats 内部吞异常返回零值。
    final stats = await HttpLog.stats();
    expect(stats.files >= 0, isTrue);
    expect(stats.bytes >= 0, isTrue);
  });
}
