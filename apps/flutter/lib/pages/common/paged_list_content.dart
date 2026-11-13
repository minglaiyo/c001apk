import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/common_body.dart';
import '../../pages/common/common_controller.dart';
import '../../pages/home/return_top_controller.dart';

/// 分页列表 Content 的统一骨架。
///
/// 承担每个列表 Content 都在重复的样板：注册业务 controller（带 tag）、
/// 注入滚动与刷新资产、监听“回到顶部”广播、离开时释放。
/// 页面级 Scaffold 与 TabBar 仍由各页面自己组装。
///
/// ```dart
/// PagedListContent<CoolpicController>(
///   tag: type + title + random,
///   returnTopTag: title + random,
///   tabIndex: 0,
///   createController: () => CoolpicController(type: type, title: title),
/// )
/// ```
class PagedListContent<C extends CommonController> extends StatefulWidget {
  const PagedListContent({
    super.key,
    required this.createController,
    required this.tag,
    required this.returnTopTag,
    this.tabIndex,
    this.leading,
  });

  final C Function() createController;

  /// 业务 controller 的注册 tag（随机段由页面生成，防重入）。
  final String tag;

  /// ReturnTopController 的查找 tag。
  final String returnTopTag;

  /// “回到顶部”广播中本页对应的索引；为 null 时不监听。
  final int? tabIndex;

  /// 列表头部附加内容，透传给 commonBody。
  final Widget? leading;

  @override
  State<PagedListContent<C>> createState() => _PagedListContentState<C>();
}

class _PagedListContentState<C extends CommonController>
    extends State<PagedListContent<C>> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final C _controller = widget.createController();
  final _scrollController = ScrollController();
  StreamSubscription<int>? _returnTopSubscription;

  @override
  void initState() {
    super.initState();
    _controller.refreshKey = GlobalKey<RefreshIndicatorState>();
    _controller.scrollController = _scrollController;
    _controller.returnTopController =
        Get.find<ReturnTopController>(tag: widget.returnTopTag);
    if (widget.tabIndex != null) {
      final tabIndex = widget.tabIndex!;
      _returnTopSubscription =
          _controller.returnTopController?.index.listen((index) {
        if (index == tabIndex) {
          _controller.animateToTop();
        }
      });
    }
  }

  @override
  void dispose() {
    _returnTopSubscription?.cancel();
    _scrollController.dispose();
    Get.delete<C>(tag: widget.tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return commonBody(_controller, leading: widget.leading);
  }
}
