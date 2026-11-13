import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/dialog/dialog_route.dart';

import '../constants/app_motion.dart';

/// 以标准的“自底滑入”转场打开一个页面级弹层。
///
/// 全应用的弹层入口统一走这里（回复列表、更多面板等）：
/// 时长与曲线取自动效 token，替代逐处手写的
/// GetDialogRoute + SlideTransition / showCupertinoModalBottomSheet 样板。
///
/// 推送在当前 [context] 所属的 navigator 上——双栏阅读模式下
/// 需要在内嵌 pane 内展示的调用点依赖这一行为。
Future<T?> showBottomSheetPage<T>({
  required BuildContext context,
  required Widget page,
}) {
  return Navigator.of(context).push(
    GetDialogRoute<T>(
      pageBuilder: (_, animation, __) => page,
      transitionDuration: AppDurations.sheet,
      transitionBuilder: (context, animation, _, child) {
        final offset = Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: AppCurves.sheetEnter));
        return SlideTransition(
          position: animation.drive(offset),
          child: child,
        );
      },
    ),
  );
}
