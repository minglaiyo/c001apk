import 'package:flutter/material.dart';

/// 应用统一的确认对话框：弹出 AlertDialog，返回用户是否点击了确认。
///
/// 确认按钮为 M3 强调样式的 FilledButton；[danger] 为 true 时
/// 使用错误配色，用于删除、移除等破坏性操作。
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  String? content,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: content == null ? null : Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
