import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../constants/app_motion.dart';

/// 滚动方向驱动的显隐动画：向上滚动时显示、向下滚动时隐藏。
///
/// 拥有并驱动 AnimationController（时长取 [AppDurations.scrollHide]），
/// 通过 [builder] 把动画交给调用方套各自的过渡样式
/// （如 ScrollHidingAction 的淡入上滑、feed 页的全幅滑入）。
class ScrollHideAnimator extends StatefulWidget {
  const ScrollHideAnimator({
    super.key,
    required this.scrollController,
    this.enabled = true,
    this.onVisibilityChanged,
    required this.builder,
  });

  /// 监听其用户滚动方向；为 null 时保持显示。
  final ScrollController? scrollController;

  /// 为 false 时不启动动画、保持显示（如未登录时的发布按钮）。
  final bool enabled;

  /// 显隐状态变化回调（true=显示）。
  final ValueChanged<bool>? onVisibilityChanged;

  final Widget Function(BuildContext context, Animation<double> animation)
      builder;

  @override
  State<ScrollHideAnimator> createState() => _ScrollHideAnimatorState();
}

class _ScrollHideAnimatorState extends State<ScrollHideAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.scrollHide,
  );
  late bool _visible = true;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _controller.forward();
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void didUpdateWidget(ScrollHideAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.forward();
      widget.scrollController?.addListener(_onScroll);
    }
  }

  void _onScroll() {
    final ScrollDirection? direction =
        widget.scrollController?.position.userScrollDirection;
    if (direction == ScrollDirection.forward) {
      _show();
    } else if (direction == ScrollDirection.reverse) {
      _hide();
    }
  }

  void _show() {
    if (!_visible) {
      _visible = true;
      _controller.forward();
      widget.onVisibilityChanged?.call(true);
    }
  }

  void _hide() {
    if (_visible) {
      _visible = false;
      _controller.reverse();
      widget.onVisibilityChanged?.call(false);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
