import 'package:c001apk_flutter/components/network_image.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flutter/material.dart';

import '../../logic/model/feed/entity.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';
import '../mouse_drag_scroll.dart';

class IconLinkGridCard extends StatefulWidget {
  const IconLinkGridCard({super.key, required this.dataList});

  final List<Entity> dataList;

  @override
  State<IconLinkGridCard> createState() => _IconLinkGridCardState();
}

class _IconLinkGridCardState extends State<IconLinkGridCard> {
  late int _page;
  final PageController _controller = PageController();

  @override
  void initState() {
    super.initState();
    _page = widget.dataList.length ~/ 5;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.hardEdge,
      color: Theme.of(context).colorScheme.onInverseSurface,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseDragScroll(
            child: ExpandablePageView.builder(
              controller: _controller,
              itemCount: _page,
              pageSnapping: true,
              itemBuilder: (context, page) {
                return Row(
                  children: [
                    _iconLinkGridCardItem(widget.dataList[page * 5]),
                    _iconLinkGridCardItem(widget.dataList[page * 5 + 1]),
                    _iconLinkGridCardItem(widget.dataList[page * 5 + 2]),
                    _iconLinkGridCardItem(widget.dataList[page * 5 + 3]),
                    _iconLinkGridCardItem(widget.dataList[page * 5 + 4]),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconLinkGridCardItem(Entity data) {
    return Expanded(
      flex: 1,
      child: InkWell(
        onTap: () => Utils.onOpenLink(data.url.orEmpty, data.title, true, context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              networkImage(
                data.pic.orEmpty,
                height: 30,
                width: 30,
                borderRadius: BorderRadius.circular(8),
              ),
              Text(
                data.title.orEmpty,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
