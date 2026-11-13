import 'package:c001apk_flutter/logic/media/feed_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coolapk CDN list thumbnails use the .m.jpg variant', () {
    expect(
        FeedMedia.fromUrl('https://image.coolapk.com/a/photo.jpg')
            .thumbnailUrl,
        'https://image.coolapk.com/a/photo.jpg.m.jpg');
    expect(
        FeedMedia.fromUrl('https://image.coolapk.com/a/photo.s.jpg')
            .thumbnailUrl,
        'https://image.coolapk.com/a/photo.m.jpg');
    expect(
        FeedMedia.fromUrl('https://image.coolapk.com/a/photo.m.jpg?x=1')
            .thumbnailUrl,
        'https://image.coolapk.com/a/photo.m.jpg');
    expect(
        FeedMedia.fromUrl('http://image.coolapk.com/a/photo.jpg')
            .thumbnailUrl,
        'https://image.coolapk.com/a/photo.jpg.m.jpg');
  });

  test('viewer originals, GIFs, live photos and other hosts untouched', () {
    const gif = 'https://image.coolapk.com/a/demo.gif';
    expect(FeedMedia.fromUrl(gif).thumbnailUrl, gif);
    expect(FeedMedia.fromUrl(gif).originalUrl, gif);
    const live = 'https://image.coolapk.com/a/livepic@1080x1920.jpg';
    expect(
        const FeedMedia(sourceUrl: live, isLivePhoto: true).thumbnailUrl,
        live);
    const other = 'https://example.com/a/photo.jpg';
    expect(FeedMedia.fromUrl(other).thumbnailUrl, other);
    const png = 'https://image.coolapk.com/a/photo.png';
    expect(FeedMedia.fromUrl(png).thumbnailUrl, png);
  });

  test('server-provided preview wins over the generated variant', () {
    expect(
        const FeedMedia(
          sourceUrl: 'https://image.coolapk.com/a/photo.jpg',
          previewUrl: 'https://image.coolapk.com/a/preview.jpg',
        ).thumbnailUrl,
        'https://image.coolapk.com/a/preview.jpg');
  });
}
