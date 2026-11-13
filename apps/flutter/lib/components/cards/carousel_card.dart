import '../../router/link_resolver.dart';
import 'dart:async';

import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';


import '../../logic/model/feed/entity.dart';
import '../../utils/extensions.dart';
import '../mouse_drag_scroll.dart';

class CarouselCard extends StatefulWidget {
  const CarouselCard({super.key, required this.dataList});

  final List<Entity> dataList;

  @override
  State<CarouselCard> createState() => _CarouselCardState();
}

class _CarouselCardState extends State<CarouselCard> {
  late List<Entity> _filterList;
  late PageController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _filterList = widget.dataList.where((item) {
      return item.url?.startsWith('http') == false;
    }).toList();

    if (_filterList.length != 1) {
      _filterList.insert(0, _filterList.last);
      _filterList.add(_filterList[1]);
    }

    _controller = PageController(initialPage: _filterList.length == 1 ? 0 : 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) => SizedBox(
              // Server home banners are ~4.45:1 (measured on two live
              // banners). width/3 made the box taller than the image, so
              // BoxFit.contain left ~18 logical dark bands above and
              // below it inside the card, which read as oversized gaps
              // to the neighbouring components. Match the box to the
              // banner aspect so the image fills it and the gaps fall
              // back to the normal 10.
              height: (constraints.maxWidth / 4.5).clamp(0.0, 240.0),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: Stack(
                  alignment: AlignmentDirectional.bottomEnd,
                  children: [
                    MouseDragScroll(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _filterList.length,
                        pageSnapping: true,
                        onPageChanged: (index) async {
                          if (_filterList.length != 1) {
                            if (index == _filterList.length - 1) {
                              _timer?.cancel();
                              _timer =
                                  Timer(const Duration(milliseconds: 500), () {
                                _controller.jumpToPage(1);
                              });
                            } else if (index == 0) {
                              _timer?.cancel();
                              _timer =
                                  Timer(const Duration(milliseconds: 500), () {
                                _controller.jumpToPage(_filterList.length - 2);
                              });
                            } else {
                              _timer?.cancel();
                            }
                          }
                        },
                        itemBuilder: (context, page) {
                          return GestureDetector(
                            onTap: () => openLink(
                              _filterList[page].url.orEmpty,
                              _filterList[page].title,
                              true,
                              context,
                            ),
                            child: networkImage(
                              _filterList[page].pic.orEmpty,
                              fit: BoxFit.contain,
                              borderRadius: null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ));
  }
}
