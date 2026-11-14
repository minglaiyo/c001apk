// 逐个量化 assets/emojis 下的 PNG（≤256 色、无抖动），只在产物更小时写回。
// 用法：dart run bin/compress_emojis.dart <emoji 目录> [--dry-run]
import 'dart:io';

import 'package:image/image.dart' as img;

const _maxColors = 256;
const _edgeFloor = 96;

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final dirPath =
      args.where((a) => !a.startsWith('--')).isEmpty ? '.' : args.firstWhere((a) => !a.startsWith('--'));
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    stderr.writeln('目录不存在: $dirPath');
    exit(1);
  }

  var beforeTotal = 0;
  var afterTotal = 0;
  var changed = 0;
  var skipped = 0;

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final original = file.readAsBytesSync();
    final decoded = img.decodePng(original);
    if (decoded == null) {
      stderr.writeln('解码失败，跳过: ${file.path}');
      skipped++;
      continue;
    }

    // 表情为小尺寸扁平图形：256 色量化 + 无抖动可保持观感。
    final quantized = _quantizeKeepingAlpha(decoded, _maxColors);
    final encoded = quantized == null
        ? original
        : img.encodePng(quantized);

    beforeTotal += original.length;
    if (quantized != null && encoded.length < original.length) {
      afterTotal += encoded.length;
      changed++;
      if (!dryRun) {
        file.writeAsBytesSync(encoded);
      }
      final kb = (original.length / 1024).toStringAsFixed(1);
      final nk = (encoded.length / 1024).toStringAsFixed(1);
      print('${file.uri.pathSegments.last}: $kb KB -> $nk KB');
    } else {
      afterTotal += original.length;
      skipped++;
      print('${file.uri.pathSegments.last}: 量化无收益，保留原样');
    }
  }

  print('---');
  print('文件数 ${files.length}，压缩 $changed，跳过 $skipped');
  print('体积 ${(beforeTotal / 1024 / 1024).toStringAsFixed(2)} MB -> '
      '${(afterTotal / 1024 / 1024).toStringAsFixed(2)} MB');
  if (dryRun) {
    print('（dry-run：未写回任何文件）');
  }
}

/// Median-cut over RGBA, so a palette entry can never mix two alpha values.
///
/// [img.quantize] trains its quantizer on blue/green/red only, so the fully
/// transparent background and the dark opaque pixels of the artwork collapse
/// into one entry and the encoder has no alpha left to write. The result was
/// an emoji drawn on a solid black rectangle.
img.Image? _quantizeKeepingAlpha(img.Image src, int maxColors) {
  final width = src.width;
  final height = src.height;
  final opaque = <int>[];
  final semi = <int>[];
  var transparent = 0;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = src.getPixel(x, y);
      final a = p.a.toInt();
      final packed = (a << 24) |
          (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
      if (a == 0) {
        transparent++;
      } else if (a == 255) {
        opaque.add(packed);
      } else {
        semi.add(packed);
      }
    }
  }

  var budget = maxColors - (transparent > 0 ? 1 : 0);
  if (budget < 1) return null;

  // Edge pixels are far fewer than body pixels but need enough alpha steps to
  // stay smooth, so they get a floor rather than a strict share.
  var semiColors = 0;
  if (semi.isNotEmpty) {
    if (opaque.isEmpty) {
      semiColors = budget;
    } else {
      final share = (budget * semi.length / (semi.length + opaque.length)).round();
      final floor = share < _edgeFloor ? _edgeFloor : share;
      semiColors = floor > budget - 1 ? budget - 1 : floor;
    }
    budget -= semiColors;
  }
  if (opaque.isNotEmpty && budget < 1) return null;

  final entries = <int>[];
  var transparentIndex = -1;
  if (transparent > 0) {
    transparentIndex = entries.length;
    entries.add(0);
  }
  final opaqueStart = entries.length;
  for (final box in _medianCut(opaque, budget)) {
    entries.add(_meanOf(box));
  }
  final semiStart = entries.length;
  for (final box in _medianCut(semi, semiColors)) {
    entries.add(_meanOf(box));
  }

  final palette = img.PaletteUint8(entries.length, 4);
  for (var i = 0; i < entries.length; i++) {
    final v = entries[i];
    palette
      ..set(i, 3, (v >> 24) & 0xff)
      ..set(i, 0, (v >> 16) & 0xff)
      ..set(i, 1, (v >> 8) & 0xff)
      ..set(i, 2, v & 0xff);
  }

  final out = img.Image(
    width: width,
    height: height,
    numChannels: 1,
    palette: palette,
  );
  // Distinct colours are a small fraction of the pixels, so resolve each one
  // once instead of scanning the palette per pixel.
  final byColor = <int, int>{};
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = src.getPixel(x, y);
      final a = p.a.toInt();
      final packed = (a << 24) |
          (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
      var index = byColor[packed];
      if (index == null) {
        // A pixel only ever maps inside its own alpha group, so a transparent
        // pixel cannot pick up a faint veil and an edge pixel cannot punch a
        // hole. Searching other groups would trade one artefact for another.
        index = a == 0
            ? transparentIndex
            : a == 255
                ? _nearest(entries, packed, opaqueStart, semiStart)
                : _nearest(entries, packed, semiStart, entries.length);
        byColor[packed] = index;
      }
      out.setPixelIndex(x, y, index);
    }
  }
  return out;
}

class _Box {
  final List<int> colors;
  final List<int> lo = [255, 255, 255, 255];
  final List<int> hi = [0, 0, 0, 0];

  _Box(this.colors) {
    for (final v in colors) {
      for (var c = 0; c < 4; c++) {
        final x = (v >> (24 - 8 * c)) & 0xff;
        if (x < lo[c]) lo[c] = x;
        if (x > hi[c]) hi[c] = x;
      }
    }
  }

  int get widestChannel {
    var best = 0;
    for (var c = 1; c < 4; c++) {
      if (hi[c] - lo[c] > hi[best] - lo[best]) best = c;
    }
    return best;
  }

  int get extent => hi[widestChannel] - lo[widestChannel];

  bool get splittable => colors.length > 1 && extent > 0;
}

/// Splits [colors] into at most [k] boxes, each split along its widest
/// channel at the median, always working on the box with the largest extent.
List<List<int>> _medianCut(List<int> colors, int k) {
  if (colors.isEmpty || k <= 1) return colors.isEmpty ? const [] : [colors];
  final boxes = <_Box>[_Box(colors)];
  while (boxes.length < k) {
    var best = -1;
    var bestScore = -1;
    for (var i = 0; i < boxes.length; i++) {
      if (!boxes[i].splittable) continue;
      final score = boxes[i].extent * 100000 + boxes[i].colors.length;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    if (best < 0) break;
    final box = boxes[best];
    final channel = box.widestChannel;
    final shift = 24 - 8 * channel;
    box.colors.sort((a, b) => ((a >> shift) & 0xff).compareTo((b >> shift) & 0xff));
    final mid = box.colors.length ~/ 2;
    boxes[best] = _Box(box.colors.sublist(mid));
    boxes.insert(best, _Box(box.colors.sublist(0, mid)));
  }
  return boxes.map((b) => b.colors).toList();
}

/// The average RGBA of a box, packed the same way as the input colours.
int _meanOf(List<int> box) {
  var r = 0, g = 0, b = 0, a = 0;
  for (final v in box) {
    a += (v >> 24) & 0xff;
    r += (v >> 16) & 0xff;
    g += (v >> 8) & 0xff;
    b += v & 0xff;
  }
  final n = box.length;
  return (((a + n / 2) ~/ n) << 24) |
      (((r + n / 2) ~/ n) << 16) |
      (((g + n / 2) ~/ n) << 8) |
      ((b + n / 2) ~/ n);
}

/// The index of the entry in [start], [end) closest to [color].
int _nearest(List<int> entries, int color, int start, int end) {
  var bestIndex = start;
  var bestScore = -1;
  for (var i = start; i < end; i++) {
    final e = entries[i];
    final da = ((e >> 24) & 0xff) - ((color >> 24) & 0xff);
    final dr = ((e >> 16) & 0xff) - ((color >> 16) & 0xff);
    final dg = ((e >> 8) & 0xff) - ((color >> 8) & 0xff);
    final db = (e & 0xff) - (color & 0xff);
    // Alpha is weighted above colour: an anti-aliased edge keeps its own
    // alpha level even when another entry's rgb would fit a little better.
    final score = 4 * da * da + dr * dr + dg * dg + db * db;
    if (bestScore < 0 || score < bestScore) {
      bestScore = score;
      bestIndex = i;
    }
    if (score == 0) break;
  }
  return bestIndex;
}
