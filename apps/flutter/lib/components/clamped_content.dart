import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;

/// 列表卡里的**正文折叠**：最多 N 行 + 「查看更多」。
///
/// 移植自 kongwufang/c001apk_next `components/clamped_html.dart`（AGPL-3.0）。
///
/// 正文经 `htmlText(...)` 渲染，底层是 widget 树而非单个 `RichText`，
/// 没有 `maxLines`，因此：
/// 1. 用 `TextPainter` 按同样字号/行高量一遍纯文本，判断是否超过 N 行；
/// 2. 超过则 `ConstrainedBox + ClipRect` 裁到 N 行；
/// 3. 下方补「查看更多」，由调用方决定跳转到详情。
///
/// 量纯文本是可靠的：正文里的 `<a>`/`<b>` 都是行内元素，不改变行数；
/// 表情是 1em 高的行内图，同样不改变行数。
class ClampedHtml extends StatelessWidget {
  const ClampedHtml({
    super.key,
    required this.child,
    required this.plainText,
    required this.onMore,
    this.maxLines = 5,
    this.fontSize = 16,
    this.height = 1.5,
    this.moreLabel = '查看更多',
  });

  /// 完整的富文本正文。
  final Widget child;

  /// 用来量行数的纯文本（HTML 已剥掉）。
  final String plainText;

  /// 点「查看更多」。
  final VoidCallback onMore;

  /// 折叠后的行数。
  final int maxLines;

  /// 正文字号。
  final double fontSize;

  /// 行高倍数。
  final double height;

  final String moreLabel;

  /// 把 HTML 剥成纯文本：正文结构规整（文本 + `<a>` 包起来的话题标签），
  /// 解析后取文本即可；解析失败退回原文，量行数偏一点比整块不显示好。
  static String stripHtml(String html) {
    if (!html.contains('<')) return html;
    try {
      final text = html_parser.parse(html).documentElement?.text;
      if (text != null && text.isNotEmpty) return text;
    } catch (_) {}
    return html;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽度无界时不折叠（放在 Row / 横向滚动里时）。
        if (!constraints.hasBoundedWidth) return child;

        final painter = TextPainter(
          text: TextSpan(
            text: plainText,
            style: TextStyle(fontSize: fontSize, height: height),
          ),
          maxLines: maxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final truncated = painter.didExceedMaxLines;
        painter.dispose();
        if (!truncated) return child;

        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: maxLines * fontSize * height),
              child: ClipRect(child: child),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onMore,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  moreLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 个人主页的**签名**：折叠 N 行 + 「展开 / 收起」。
///
/// 移植自 kongwufang/c001apk_next `components/expandable_bio.dart`（AGPL-3.0）。
/// 关键口径：**只有真被截断才显示「展开」**——一行的签名不该冒出展开按钮。
/// 用 `TextPainter` 在布局前量出是否溢出，比等一帧再判断更省事。
class ExpandableBio extends StatefulWidget {
  const ExpandableBio({
    super.key,
    required this.text,
    this.collapsedLines = 2,
    this.fontSize,
    this.color,
    this.padding = const EdgeInsets.only(left: 20, top: 4),
  });

  final String text;

  /// 折叠态保留几行（官方 `BIO_COLLAPSED_LINES = 2`）。
  final int collapsedLines;

  final double? fontSize;
  final Color? color;
  final EdgeInsets padding;

  @override
  State<ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<ExpandableBio> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
          TextStyle(fontSize: widget.fontSize, color: widget.color),
        );
    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: null,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: constraints.maxWidth);
          final needsExpand =
              painter.computeLineMetrics().length > widget.collapsedLines;
          painter.dispose();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : widget.collapsedLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              // 只有真被截断才露「展开」；展开后必定露「收起」。
              if (needsExpand || _expanded)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _expanded ? '收起' : '展开',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
