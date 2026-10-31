import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/common_body.dart';
import '../../pages/product/product_detail.dart';
import '../../pages/product/product_feed_controller.dart';

class ProductFeedContent extends StatefulWidget {
  const ProductFeedContent({
    super.key,
    required this.productId,
    required this.tab,
  });

  final String productId;
  final ProductTab tab;

  @override
  State<ProductFeedContent> createState() => _ProductFeedContentState();
}

class _ProductFeedContentState extends State<ProductFeedContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final _controller = Get.put(
    ProductFeedController(productId: widget.productId, tab: widget.tab),
    tag: '${widget.productId}${widget.tab.key}',
  );

  @override
  void dispose() {
    _controller.scrollController?.dispose();
    Get.delete<ProductFeedController>(
      tag: '${widget.productId}${widget.tab.key}',
    );
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.refreshKey = GlobalKey<RefreshIndicatorState>();
    _controller.scrollController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return commonBody(_controller);
  }
}
