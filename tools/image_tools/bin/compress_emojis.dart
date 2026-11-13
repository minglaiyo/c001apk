// 逐个量化 assets/emojis 下的 PNG（≤256 色、无抖动），只在产物更小时写回。
// 用法：dart run bin/compress_emojis.dart <emoji 目录> [--dry-run]
import 'dart:io';

import 'package:image/image.dart' as img;

const _maxColors = 256;

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
    final quantized = img.quantize(
      decoded,
      numberOfColors: _maxColors,
      dither: img.DitherKernel.none,
    );
    final encoded = img.encodePng(quantized);

    beforeTotal += original.length;
    if (encoded.length < original.length) {
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
