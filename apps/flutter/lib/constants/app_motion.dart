import 'package:flutter/animation.dart';

/// 全局动效时长 token。
///
/// 页面转场、弹层、滚动显隐等动画统一从这里取值，
/// 替代散落在各文件里的 `Duration(milliseconds: ...)` 字面量。
abstract final class AppDurations {
  /// 页面转场（Android 预测性返回 / 桌面 fade-forwards）。
  static const pageTransition = Duration(milliseconds: 450);

  /// 底部弹层（回复列表、更多面板）滑入。
  static const sheet = Duration(milliseconds: 350);

  /// 滚动显隐（FAB、发布按钮）。
  static const scrollHide = Duration(milliseconds: 300);

  /// 主页 Tab 切换与导航栏形变。
  static const viewSwitch = Duration(milliseconds: 400);

  /// 快速反馈（刷新悬浮指示器、对话框内容切换）。
  static const fast = Duration(milliseconds: 150);

  /// 图片查看器的缩放过渡。
  static const imageViewer = Duration(milliseconds: 255);
}

/// 全局动效曲线 token。
abstract final class AppCurves {
  /// 页面切换、Tab 切换等标准过渡（Material 3 emphasized）。
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// 底部弹层进入。
  static const sheetEnter = Curves.easeOutCubic;

  /// 滚动显隐（正向显示、反向隐藏共用）。
  static const scrollHide = Curves.easeInOut;
}
