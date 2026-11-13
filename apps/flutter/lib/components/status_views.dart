import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import 'expressive_loading_indicator.dart';

/// 列表页统一状态视图的基块：整块 80 高、居中文本，与 commonBody、
/// footer 的空态、错误态、加载态保持同一样式。
///
/// [onTap] 为空时整块不可点击（如被屏蔽用户的错误态）。
class StatusTile extends StatelessWidget {
  const StatusTile({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        alignment: Alignment.center,
        padding: AppSpacing.pageInsets,
        child: Text(text),
      ),
    );
  }
}

/// 空态，默认文案“暂无内容”。
class EmptyStatusView extends StatelessWidget {
  const EmptyStatusView({super.key, this.text = '暂无内容', this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => StatusTile(text: text, onTap: onTap);
}

/// 错误态：展示错误信息，点击触发重试。
class ErrorStatusView extends StatelessWidget {
  const ErrorStatusView({super.key, required this.message, this.onTap});

  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => StatusTile(text: message, onTap: onTap);
}

/// 加载态：居中的 expressive 形变指示器。
class LoadingStatusView extends StatelessWidget {
  const LoadingStatusView({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        alignment: Alignment.center,
        padding: AppSpacing.pageInsets,
        child: const ExpressiveLoadingIndicator(),
      );
}
