import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 长按条目弹出的操作面板中的一个动作。
class MorePanelAction {
  const MorePanelAction({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;

  /// 点击后触发；面板会先自行关闭再调用本回调。
  final VoidCallback onSelected;
}

/// 操作面板本体：顶部拖拽把手 + 动作列表。
///
/// 动作内容由调用方组装（各卡片的屏蔽/删除/举报条件各不相同），
/// 展示样式与“先关面板、再执行动作”的顺序在此统一。
class MorePanel extends StatelessWidget {
  const MorePanel({super.key, required this.actions});

  final List<MorePanelAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            onTap: () => Get.back(),
            child: Container(
              alignment: Alignment.center,
              height: 35,
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          for (final action in actions)
            ListTile(
              onTap: () {
                Get.back();
                action.onSelected();
              },
              minLeadingWidth: 0,
              leading: Icon(action.icon, size: 19),
              title: Text(action.label,
                  style: Theme.of(context).textTheme.titleSmall),
            ),
        ],
      ),
    );
  }
}

/// 以底部弹层方式展示操作面板。
Future<T?> showMorePanel<T>({
  required BuildContext context,
  required List<MorePanelAction> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => MorePanel(actions: actions),
  );
}
