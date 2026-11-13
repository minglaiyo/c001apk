import '../../router/link_resolver.dart';
import '../../utils/share_util.dart';
import '../../constants/app_sizes.dart';
import '../more_panel.dart';
import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

import '../../components/html_text.dart';
import '../../components/imageview.dart';
import '../../logic/model/feed/datum.dart';
import '../../utils/date_util.dart';
import '../../utils/extensions.dart';
import '../../utils/storage_util.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.data,
    this.onBlock,
    this.onDelete,
  });

  final Datum data;
  final Function(dynamic uid)? onBlock;
  final Function(dynamic id)? onDelete;

  @override
  Widget build(BuildContext context) {
    final isFollow = data.type == 'contacts_follow';
    return Material(
      color: Theme.of(context).colorScheme.onInverseSurface,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: () {
          if (isFollow) {
            openLink(data.url ?? '');
          } else {
            dom.Document document = parse(data.note);
            String? link = document
                .querySelectorAll('a[href]')
                .firstOrNull
                ?.attributes['href'];
            if (link != null) {
              openLink(link);
            }
          }
        },
        onLongPress: () =>
            Get.toNamed('/copy', parameters: {'text': data.note ?? ''}),
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                  onPressed: () => showMorePanel(
                        context: context,
                        actions: [
                          MorePanelAction(
                            icon: Icons.delete_outline,
                            label: '删除',
                            onSelected: () => onDelete?.call(data.id),
                          ),
                          MorePanelAction(
                            icon: Icons.block,
                            label: '屏蔽',
                            onSelected: () {
                              GStorage.onBlock(data.fromuid);
                              onBlock?.call(data.uid);
                            },
                          ),
                          MorePanelAction(
                              icon: Icons.error_outline,
                              label: '举报',
                              onSelected: () =>
                                  report(data.fromuid, ReportType.User),
                            ),
                        ],
                      ),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.outline,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () =>
                        Get.toNamed('/u/${data.fromuid ?? data.uid ?? ''}'),
                    child: clipNetworkImage(
                      data.fromUserAvatar ?? '',
                      isAvatar: true,
                      width: 30,
                      height: 30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        htmlText(data.fromusername ?? ''),
                        htmlText(
                          data.note ?? '',
                          onViewFan: isFollow
                              ? () => Get.toNamed('/u/${data.fromuid}')
                              : null,
                        ),
                        if (!data.picArr.isNullOrEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                double maxWidth = constraints.maxWidth;
                                return image(
                                  maxWidth,
                                  data.picArr!,
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 5),
                        Text(
                          DateUtil.fromToday(data.dateline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

