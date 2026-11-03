import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../logic/model/feed/datum.dart';
import '../../logic/model/feed/vote_model.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../utils/global_data.dart';

/// 动态投票卡片，B 层参考级。
///
/// 未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码：提交是
/// POST /v6/vote/createUserVote，表单 id + select_option[0..n] +
/// anonymous_status。vote 对象内层键名未经实测，由 vote_model.dart
/// 宽容解析；读不到选项时只显示“投票数据未识别”而不崩溃。
/// 投票后本地只标记已选选项（票数以服务端为准，未实测前不编造）。
class VoteCard extends StatefulWidget {
  const VoteCard({super.key, required this.data});

  final Datum data;

  @override
  State<VoteCard> createState() => _VoteCardState();
}

class _VoteCardState extends State<VoteCard> {
  late VoteData _vote = parseVote(widget.data.vote);
  final _selected = <String>{};
  bool _anonymous = false;
  bool _busy = false;
  bool _submitted = false;

  bool get _voted =>
      _submitted || _vote.votedOptionIds.isNotEmpty;

  int get _maxVotes {
    var max = 0;
    for (final option in _vote.options) {
      if ((option.votes ?? 0) > max) max = option.votes!;
    }
    return max;
  }

  Future<void> _submit() async {
    if (_busy || _selected.isEmpty) return;
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
    setState(() => _busy = true);
    try {
      final response = await NetworkRepo.postVote(
        feedId: widget.data.id,
        optionIds: _selected.toList(),
        anonymous: _anonymous,
      );
      // 成功回包可能 message-only（产品关注先例），勿用默认 data 校验。
      readApiObject(response, allowSuccessWithoutData: true);
      if (mounted) {
        setState(() {
          _submitted = true;
          _vote = VoteData(
            recognized: true,
            options: _vote.options,
            votedOptionIds: {..._vote.votedOptionIds, ..._selected},
            totalVotes: _vote.totalVotes,
            isMulti: _vote.isMulti,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投票成功（参考接口首次实测，请核对票数是否变化）')),
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
    if (!_vote.recognized) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Text('投票数据未识别（参考未实测，待真机样本）'),
      );
    }
    final votedIds =
        _voted ? _vote.votedOptionIds : const <String>{};
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote_outlined, size: 16),
              const SizedBox(width: 4),
              Text(_voted ? '投票（已投票）' : '投票'),
              if (_vote.totalVotes != null) ...[
                const SizedBox(width: 8),
                Text('${_vote.totalVotes} 票'),
              ],
            ],
          ),
          const SizedBox(height: 8),
          for (final option in _vote.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _voted
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(option.label),
                              const SizedBox(height: 2),
                              LinearProgressIndicator(
                                value: _maxVotes > 0
                                    ? ((option.votes ?? 0) / _maxVotes)
                                        .clamp(0.0, 1.0)
                                    : 0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (option.votes != null) Text('${option.votes}'),
                        if (votedIds.contains(option.id))
                          const Icon(Icons.check, size: 16),
                      ],
                    )
                  : CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(option.label),
                      subtitle: option.votes != null
                          ? Text('${option.votes} 票')
                          : null,
                      value: _selected.contains(option.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (!_vote.isMulti) _selected.clear();
                            _selected.add(option.id);
                          } else {
                            _selected.remove(option.id);
                          }
                        });
                      },
                    ),
            ),
          if (!_voted) ...[
            Row(
              children: [
                Checkbox(
                  value: _anonymous,
                  onChanged: (value) =>
                      setState(() => _anonymous = value ?? false),
                ),
                const Text('匿名投票'),
                const Spacer(),
                FilledButton(
                  onPressed: _busy || _selected.isEmpty ? null : _submit,
                  child: Text(_busy ? '提交中…' : '投票'),
                ),
              ],
            ),
            const Text(
              '投票接口为未实测参考，首次提交即当探针；失败时请报提示。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// 供 FeedCard 复用的判定：有 vote 原始对象即尝试渲染。
bool hasVoteData(Datum data) => data.vote != null && data.vote!.isNotEmpty;
