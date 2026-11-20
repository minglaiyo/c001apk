import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/material.dart';

import '../utils/emoji_util.dart';
import 'clamped_content.dart';

/// 列表卡正文预览：把消息 HTML 解析成**单一 TextSpan 树**（含
/// [WidgetSpan] 表情图），交给原生 `Text.rich(maxLines: …)` 截断。
///
/// 参考 bggRGjQaUbCoE/PiliPlus 的 TextMore/richNodes 方案：截断由文本
/// 引擎自己做——行盒精确，任何字体、任何 textScaler 下都不可能出现
/// 「最后一行底部被裁掉」。不再对 widget 树做量行 + ClipRect。
/// 「是否截断」的判定用同一棵 span 树、同一样式、同一 textScaler、
/// 同一宽度的 TextPainter（表情占位尺寸手动注入），与渲染零误差。
class RichPreview extends StatelessWidget {
  const RichPreview({
    super.key,
    required this.source,
    required this.maxLines,
    required this.onMore,
    this.fontSize = 16,
    this.lineHeight = 1.5,
    this.moreLabel = '查看更多',
  });

  /// 消息原文（酷安 HTML 片段）。
  final String source;

  final int maxLines;
  final VoidCallback onMore;
  final double fontSize;
  final double lineHeight;
  final String moreLabel;

  static final _emojiToken = RegExp('\\[[^\\]]+\\]');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = TextStyle(fontSize: fontSize, height: lineHeight);
    final emojiSize = MediaQuery.textScalerOf(context).scale(fontSize) * 1.3;
    final spans = <InlineSpan>[];
    final placeholders = <PlaceholderDimensions>[];
    _buildSpans(
      html_parser.parse(source).body,
      spans,
      placeholders,
      base,
      colors,
      emojiSize,
      context,
      bold: false,
      link: false,
    );

    final tree = TextSpan(style: base, children: spans);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: tree,
          maxLines: maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          textWidthBasis: TextWidthBasis.parent,
        )
          ..setPlaceholderDimensions(placeholders)
          ..layout(maxWidth: constraints.maxWidth);
        final truncated = painter.didExceedMaxLines;
        painter.dispose();
        final text = Text.rich(
          tree,
          maxLines: truncated ? maxLines : null,
          overflow:
              truncated ? TextOverflow.ellipsis : TextOverflow.visible,
        );
        if (!truncated) return text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            text,
            const SizedBox(height: 6),
            ClampedMoreButton(label: moreLabel, onTap: onMore),
          ],
        );
      },
    );
  }

  /// 递归把 DOM 节点映射成 InlineSpan；表情图占位尺寸记入
  /// [placeholders]（测量与渲染共用同一棵树）。
  void _buildSpans(
    dom.Node? node,
    List<InlineSpan> spans,
    List<PlaceholderDimensions> placeholders,
    TextStyle style,
    ColorScheme colors,
    double emojiSize,
    BuildContext context, {
    required bool bold,
    required bool link,
  }) {
    if (node == null) return;
    if (node is dom.Text) {
      final text = node.text;
      var last = 0;
      for (final match in _emojiToken.allMatches(text)) {
        final before = text.substring(last, match.start);
        if (before.isNotEmpty) {
          spans.add(TextSpan(
              text: before,
              style: style.copyWith(
                fontWeight: bold ? FontWeight.bold : null,
                color: link ? colors.primary : null,
                decoration: link ? TextDecoration.none : null,
              )));
        }
        final token = match.group(0) ?? '';
        final src = EmojiUtil.emojiMap[token];
        if (src == null) {
          spans.add(TextSpan(
              text: token,
              style: style.copyWith(
                fontWeight: bold ? FontWeight.bold : null,
                color: link ? colors.primary : null,
                decoration: link ? TextDecoration.none : null,
              )));
        } else if (src.endsWith('.png')) {
          // 表情图：WidgetSpan 进 span 树，原生 maxLines 连占位符一起截断。
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Image.asset('assets/emojis/$src',
                width: emojiSize, height: emojiSize),
          ));
          placeholders.add(PlaceholderDimensions(
            size: Size(emojiSize, emojiSize),
            alignment: PlaceholderAlignment.middle,
          ));
        } else if (src.endsWith('icon')) {
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(Icons.photo_outlined,
                size: emojiSize, color: colors.primary),
          ));
          placeholders.add(PlaceholderDimensions(
            size: Size(emojiSize, emojiSize),
            alignment: PlaceholderAlignment.middle,
          ));
        } else {
          spans.add(TextSpan(
              text: token,
              style: style.copyWith(
                fontSize: fontSize - 4,
                fontWeight: FontWeight.bold,
                color: colors.primary,
                height: 1,
                decoration: TextDecoration.none,
              )));
        }
        last = match.end;
      }
      final rest = text.substring(last);
      if (rest.isNotEmpty) {
        spans.add(TextSpan(
            text: rest,
            style: style.copyWith(
              fontWeight: bold ? FontWeight.bold : null,
              color: link ? colors.primary : null,
              decoration: link ? TextDecoration.none : null,
            )));
      }
      return;
    }
    if (node is dom.Element) {
      switch (node.localName) {
        case 'br':
          spans.add(const TextSpan(text: '\n'));
          return;
        case 'img':
          // 非表情内联图（正文中嵌图）：列表预览不渲染，图片网格已覆盖。
          return;
        case 'b':
        case 'strong':
          for (final child in node.nodes) {
            _buildSpans(child, spans, placeholders, style, colors, emojiSize,
                context,
                bold: true, link: link);
          }
          return;
        case 'a':
          for (final child in node.nodes) {
            _buildSpans(child, spans, placeholders, style, colors, emojiSize,
                context,
                bold: bold, link: true);
          }
          return;
        default:
          // span/font/div/p 等：内容一律内联展开（酷安正文以行内元素为主）。
          for (final child in node.nodes) {
            _buildSpans(child, spans, placeholders, style, colors, emojiSize,
                context,
                bold: bold, link: link);
          }
          return;
      }
    }
  }
}
