import 'package:flutter/material.dart';

import '../../../constants/app_sizes.dart';

/// 点评表单的**数据快照**（由 [RatingPanel] 通过 `onChanged` 抛出）。
class RatingFormValue {
  const RatingFormValue({
    required this.overall,
    required this.itemStars,
    required this.good,
    required this.bad,
    required this.buyStatus,
  });

  /// 总体评分（**1~5 星**，原值提交到 `rating_score_1`）
  final int overall;

  /// 各子项的星数（1~5）；提交时要 **× 2** 变成 0~10 量纲
  final List<int> itemStars;

  final String good;
  final String bad;
  final bool buyStatus;

  /// 总体和**每个**子项都打过分才算完整。
  ///
  /// 服务端原始约束：子项必须全部 >0，漏一个或传 0 会回
  /// 「-48 子项xx没有评分」。
  bool get valid =>
      overall > 0 && itemStars.isNotEmpty && itemStars.every((e) => e > 0);
}

/// 点评评分面板：总体评分 + 各子项评分 + 优点/缺点 + 是否已购买。
///
/// 移植自 kongwufang/c001apk_next 的 `pages/feed/reply/rating_panel.dart`
/// （AGPL-3.0），对应官方 `ReplyActivity` 的 `type == "rating"` 分支。
/// 视觉改为本项目 M3 配色与圆角 token。
///
/// ## 分值量纲（实测结论，容易搞错）
/// - `rating_score_1` 是 **1~5 星原值**，6 及以上一律回「请正确打分」；
/// - `v4_score_item_1..n` 是 **0~10 量纲（每星 2 分）**，子项必须全部 >0。
///
/// 所以面板里所有控件都是 5 星，提交时总体原样、子项 ×2。
class RatingPanel extends StatefulWidget {
  const RatingPanel({
    super.key,
    required this.target,
    required this.items,
    required this.onChanged,
  });

  /// 被点评的产品名。
  final String target;

  /// 子项定义：`[{id: 'v4_score_item_1', name: '续航'}, …]`
  final List<Map<String, dynamic>> items;

  final ValueChanged<RatingFormValue> onChanged;

  @override
  State<RatingPanel> createState() => _RatingPanelState();
}

class _RatingPanelState extends State<RatingPanel> {
  int _overall = 0;
  late final List<int> _itemStars = List<int>.filled(widget.items.length, 0);
  bool _buyStatus = false;
  final _goodController = TextEditingController();
  final _badController = TextEditingController();

  @override
  void dispose() {
    _goodController.dispose();
    _badController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(RatingFormValue(
      overall: _overall,
      itemStars: List<int>.from(_itemStars),
      good: _goodController.text.trim(),
      bad: _badController.text.trim(),
      buyStatus: _buyStatus,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.target,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _starRow(
            context,
            label: '总体评分',
            value: _overall,
            onChanged: (value) {
              setState(() => _overall = value);
              _notify();
            },
          ),
          for (var i = 0; i < widget.items.length; i++)
            _starRow(
              context,
              label: widget.items[i]['name']?.toString() ?? '',
              value: _itemStars[i],
              onChanged: (value) {
                setState(() => _itemStars[i] = value);
                _notify();
              },
            ),
          const SizedBox(height: 6),
          _textField(_goodController, '优点'),
          const SizedBox(height: 8),
          _textField(_badController, '缺点'),
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              setState(() => _buyStatus = !_buyStatus);
              _notify();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Checkbox(
                  value: _buyStatus,
                  onChanged: (value) {
                    setState(() => _buyStatus = value ?? false);
                    _notify();
                  },
                ),
                Text('已购买', style: theme.textTheme.bodyMedium),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(TextEditingController controller, String hint) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: (_) => _notify(),
      maxLines: 2,
      minLines: 1,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(AppRadius.small)),
      ),
    );
  }

  /// 一行「名称 + 5 颗星 + 当前星数」。
  Widget _starRow(
    BuildContext context, {
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    final starColor = theme.colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          for (var i = 1; i <= 5; i++)
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: '$i 星',
              onPressed: () => onChanged(i),
              icon: Icon(
                i <= value ? Icons.star : Icons.star_border,
                size: 22,
                color: i <= value ? starColor : theme.colorScheme.outline,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            value == 0 ? '未评分' : '$value 星',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
