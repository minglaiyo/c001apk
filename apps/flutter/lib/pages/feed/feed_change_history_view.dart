import 'package:flutter/material.dart';

import '../../logic/network/network_repo.dart';
import '../../pages/feed/feed_change_history.dart';

/// Shows the edit history dialog for one feed, mirroring
/// coolapk-desktop's feed card "编辑记录" dialog: versions newest first,
/// the current version on top, each with its time, title, full text
/// and a change badge against the next older version.
Future<void> showFeedChangeHistoryDialog(
    BuildContext context, String feedId) {
  return showDialog(
    context: context,
    builder: (context) => _FeedChangeHistoryDialog(feedId: feedId),
  );
}

class _FeedChangeHistoryDialog extends StatefulWidget {
  const _FeedChangeHistoryDialog({required this.feedId});

  final String feedId;

  @override
  State<_FeedChangeHistoryDialog> createState() =>
      _FeedChangeHistoryDialogState();
}

class _FeedChangeHistoryDialogState extends State<_FeedChangeHistoryDialog> {
  Future<List<FeedChangeHistoryItem>>? _future;

  @override
  void initState() {
    super.initState();
    _future = NetworkRepo.getFeedChangeHistory(widget.feedId);
  }

  String _formatTime(int? timeMillis) {
    if (timeMillis == null) return '';
    final time = DateTime.fromMillisecondsSinceEpoch(timeMillis);
    return time.toString().substring(0, 16);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑记录'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<FeedChangeHistoryItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('编辑记录加载失败'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _future =
                            NetworkRepo.getFeedChangeHistory(widget.feedId);
                      });
                    },
                    child: const Text('重试'),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Text('暂无编辑记录');
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('动态每次修改的内容都会保留，当前版本显示在最上方。'),
                  const SizedBox(height: 12),
                  for (var index = 0; index < items.length; index++) ...[
                    if (index > 0) const Divider(),
                    Builder(builder: (context) {
                      final item = items[index];
                      final older =
                          index + 1 < items.length ? items[index + 1] : null;
                      final badge = feedChangeBadge(item, older);
                      final time = _formatTime(item.timeMillis);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.versionLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (badge != null) Text(badge),
                              if (time.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (item.title.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(item.content),
                          if (item.images.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: item.images
                                  .map((url) => Image.network(
                                        url,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const SizedBox.shrink(),
                                      ))
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
