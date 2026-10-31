import 'package:c001apk_flutter/logic/clipboard/clipboard_link_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coolapk hosts and coolmarket scheme are detected', () {
    expect(ClipboardLinkDetector.isCoolapkLink('https://coolapk.com/feed/1'),
        isTrue);
    expect(
        ClipboardLinkDetector.isCoolapkLink(
            'https://www.coolapk.com/t/xxx?x=1'),
        isTrue);
    expect(ClipboardLinkDetector.isCoolapkLink('coolmarket://u/123'), isTrue);
    expect(ClipboardLinkDetector.isCoolapkLink('https://example.com/feed/1'),
        isFalse);
    expect(ClipboardLinkDetector.isCoolapkLink('not a link'), isFalse);
    expect(ClipboardLinkDetector.isCoolapkLink(''), isFalse);
  });

  test('a link inside copied text is extracted', () {
    expect(
        ClipboardLinkDetector.extractCoolapkLink(
            '看看这个 https://coolapk.com/feed/123 很不错'),
        'https://coolapk.com/feed/123');
    expect(
        ClipboardLinkDetector.extractCoolapkLink('今天天气不错'), isNull);
    expect(
        ClipboardLinkDetector.extractCoolapkLink(
            'https://example.com/coolapk.com/feed/1'),
        isNull);
  });
}
