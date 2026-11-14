import 'package:flutter/widgets.dart';

/// 圆角 token。
///
/// 卡片 12 是全应用的事实标准（feed/回复/通知等列表卡片）。
abstract final class AppRadius {
  /// 列表卡片、回复面板容器。
  static const card = Radius.circular(12);

  /// 小型控件、内嵌图片。
  static const small = Radius.circular(8);

  /// 底部弹层顶部。
  static const sheet = Radius.circular(20);

  /// 玻璃面板。
  static const glass = Radius.circular(28);

  /// 便捷构造：整卡片圆角。
  static BorderRadius get cardAll => const BorderRadius.all(card);

  /// 便捷构造：小控件整圆角。
  static BorderRadius get smallAll => const BorderRadius.all(small);

  /// 便捷构造：底部弹层整圆角。
  static BorderRadius get sheetAll => const BorderRadius.all(sheet);

  /// 便捷构造：玻璃面板整圆角。
  static BorderRadius get glassAll => const BorderRadius.all(glass);
}

/// 间距 token。
///
/// 列表页与卡片内边距 10 是全应用的事实标准。
abstract final class AppSpacing {
  /// 页面左右边距与卡片内边距。
  static const page = 10.0;

  /// 卡片之间的纵向间隔。
  static const gap = 10.0;

  /// 标准四周边距。
  static const pageInsets = EdgeInsets.all(page);

  /// 标准水平边距。
  static const horizontalInsets = EdgeInsets.symmetric(horizontal: page);
}
