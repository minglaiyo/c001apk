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

  /// 控件级反馈（导航栏形变、弹层、淡入/缩放指示器）。
  static const control = Duration(milliseconds: 200);

  /// 即时吸附（滚动到目标位置等快速位移）。
  static const instant = Duration(milliseconds: 100);

  /// 尺寸过渡（AnimatedSize 等形变动画）。
  static const size = Duration(milliseconds: 250);
}

/// 全局动效曲线 token。
abstract final class AppCurves {
  /// 页面切换、Tab 切换等标准过渡（Material 3 emphasized）。
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// 底部弹层进入。
  static const sheetEnter = Curves.easeOutCubic;

  /// 滚动显隐（正向显示、反向隐藏共用）。
  static const scrollHide = Curves.easeInOut;

  /// 进入/位移收尾（控件吸附、列表项入场）。
  static const easeOut = Curves.easeOut;

  /// 通用平滑过渡（页面切换、滚动定位）。
  static const ease = Curves.ease;
}
