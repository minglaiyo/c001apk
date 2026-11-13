import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../logic/model/feed/datum.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../pages/collection/collection_dialogs.dart';
import '../../pages/ffflist/ffflist_page.dart';

class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, required this.data});

  final Datum data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed('ffflist', arguments: {
        'id': data.id.toString(),
        'title': data.title,
        'type': FFFListType.COLLECTION_ITEM,
      }),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onInverseSurface,
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            clipNetworkImage(
              data.coverPic ?? '',
              radius: 8,
              width: 53,
              height: 40,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 10),
            Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title ?? ''),
                    DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      child: Row(
                        children: [
                          Text(data.isOpenTitle ?? ''),
                          const SizedBox(width: 10),
                          Text('${data.followNum}人关注'),
                          const SizedBox(width: 10),
                          Text('${data.itemNum}个内容'),
                        ],
                      ),
                    ),
                  ],
                )),
            // 管理入口（B 层参考级）：改名 / 删除，写接口首次使用即当探针。
            // 点卡片本身仍进收藏单内容页，不受影响。
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: '管理收藏单',
              onPressed: () async {
                final action = await showModalBottomSheet<String>(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: const Text('改名'),
                          onTap: () => Navigator.of(context).pop('rename'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: const Text('删除（建议先用测试单）'),
                          onTap: () => Navigator.of(context).pop('delete'),
                        ),
                      ],
                    ),
                  ),
                );
                if (!context.mounted) return;
                if (action == 'rename') {
                  await showRenameCollectionDialog(
                    context,
                    id: data.id,
                    currentTitle: data.title ?? '',
                  );
                } else if (action == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('删除收藏单？'),
                      content: const Text(
                          '删除后其中内容的归属由服务端同时取消，建议先用测试单试。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    try {
                      final response =
                          await NetworkRepo.deleteCollection(data.id);
                      readApiObject(response, allowSuccessWithoutData: true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已删除，请刷新列表查看')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(ApiFailure.fromError(e).message)),
                        );
                      }
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
