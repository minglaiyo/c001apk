import 'package:flutter/material.dart';

import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../utils/global_data.dart';

/// 收藏单新建 / 改名对话框，B 层参考级。
///
/// 未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码：
/// POST /v6/collection/create、/update（id 必须放表单字段）。
/// 成功回包可能 message-only，调用方按 allowSuccessWithoutData 处理；
/// 失败时不改 UI，只显示提示。文案提醒先用测试单试。
Future<bool> showCreateCollectionDialog(BuildContext context) async {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  var isOpen = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('新建收藏单'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '标题（必填）'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: '简介'),
            ),
            Row(
              children: [
                Checkbox(
                  value: isOpen,
                  onChanged: (value) =>
                      setState(() => isOpen = value ?? false),
                ),
                const Text('公开'),
              ],
            ),
            const Text(
              '建议先建一个测试单试全流程；写接口为未实测参考。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('标题不能为空')),
                );
                return;
              }
              if (!GlobalData().isLogin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先登录')),
                );
                return;
              }
              try {
                final response = await NetworkRepo.createCollection(
                  title: title,
                  description: descController.text.trim(),
                  isOpen: isOpen ? 1 : 0,
                );
                readApiObject(response, allowSuccessWithoutData: true);
                if (context.mounted) Navigator.of(context).pop(true);
              } catch (e) {
                if (context.mounted) {
                  final failure = ApiFailure.fromError(e);
                  final message = failure.kind == ApiFailureKind.transport
                      ? '创建请求未到达服务端（${failure.message}），请检查网络后重试；若网络正常仍失败，请把这条提示原文发回，可能是写接口未被服务端接受。'
                      : failure.message;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

Future<bool> showRenameCollectionDialog(
  BuildContext context, {
  required dynamic id,
  required String currentTitle,
}) async {
  final titleController = TextEditingController(text: currentTitle);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('改名收藏单'),
      content: TextField(
        controller: titleController,
        decoration: const InputDecoration(labelText: '标题（必填）'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            final title = titleController.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('标题不能为空')),
              );
              return;
            }
            try {
              final response = await NetworkRepo.updateCollection(
                id: id,
                title: title,
              );
              readApiObject(response, allowSuccessWithoutData: true);
              if (context.mounted) Navigator.of(context).pop(true);
            } catch (e) {
              if (context.mounted) {
                final failure = ApiFailure.fromError(e);
                final message = failure.kind == ApiFailureKind.transport
                    ? '请求未到达服务端（${failure.message}），请检查网络后重试；若网络正常仍失败，请把这条提示原文发回。'
                    : failure.message;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              }
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  return result ?? false;
}
