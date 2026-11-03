import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../logic/model/feed/datum.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import 'collection_dialogs.dart';

/// “收藏到收藏单…”选择器，B 层参考级。
///
/// 未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码：
/// 先查 GET /v6/collection/list?uid=&id={feedId}&type=feed&showDefault=1
/// 看已在哪些单里；点已在的单 → addItem(cancelId=该单) 移出，
/// 点不在的单 → addItem(id=该单, targetId=动态) 加入。
/// 成功回包可能 message-only；失败时不改 UI，只显示提示。
Future<void> showCollectionPickerDialog(
    BuildContext context, dynamic feedId) async {
  if (!GlobalData().isLogin) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('请先登录'),
        action: SnackBarAction(
          label: '登录',
          onPressed: () => Get.toNamed('/login'),
        ),
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => _CollectionPickerDialog(feedId: feedId),
  );
}

class _CollectionPickerDialog extends StatefulWidget {
  const _CollectionPickerDialog({required this.feedId});

  final dynamic feedId;

  @override
  State<_CollectionPickerDialog> createState() =>
      _CollectionPickerDialogState();
}

class _CollectionPickerDialogState extends State<_CollectionPickerDialog> {
  List<Datum> _collections = [];
  Set<String> _contained = {};
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mine = await NetworkRepo.getDataListFromUrl(
      url: '/v6/collection/list',
      data: {'showDefault': 0, 'page': 1},
    );
    final state = await NetworkRepo.getCollectionStateForFeed(widget.feedId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (mine is Success) {
        _collections = (mine.response as List<Datum>);
      } else if (mine is Error) {
        _error = mine.errMsg;
      }
      if (state is Success) {
        _contained = {
          for (final item in (state.response as List<Datum>))
            item.id.toString()
        };
      }
    });
  }

  Future<void> _toggle(Datum collection) async {
    if (_busy) return;
    final id = collection.id.toString();
    final alreadyIn = _contained.contains(id);
    setState(() => _busy = true);
    try {
      final response = alreadyIn
          ? await NetworkRepo.addCollectionItem(
              id: '',
              cancelId: id,
              targetId: widget.feedId,
            )
          : await NetworkRepo.addCollectionItem(
              id: id,
              targetId: widget.feedId,
            );
      readApiObject(response, allowSuccessWithoutData: true);
      if (mounted) {
        setState(() {
          if (alreadyIn) {
            _contained.remove(id);
          } else {
            _contained.add(id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(alreadyIn ? '已从该收藏单移出' : '已加入该收藏单')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiFailure.fromError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('收藏到收藏单'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Text(_error!)
                : _collections.isEmpty
                    ? const Text('暂无自建收藏单，先新建一个（建议测试单）。')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '已在的单打勾；点已在的单移出，点不在的单加入。写接口为未实测参考，首次使用即当探针。',
                            style: TextStyle(fontSize: 12),
                          ),
                          Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                for (final collection in _collections)
                                  ListTile(
                                    title: Text(collection.title.orEmpty),
                                    subtitle: Text(
                                        '${collection.itemNum ?? ''}个内容'),
                                    trailing: _contained.contains(
                                            collection.id.toString())
                                        ? const Icon(Icons.check)
                                        : null,
                                    onTap: _busy
                                        ? null
                                        : () => _toggle(collection),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final created = await showCreateCollectionDialog(context);
            if (created && mounted) setState(() => _loading = true);
            if (created) _load();
          },
          child: const Text('新建收藏单'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
