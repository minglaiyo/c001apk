import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

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
  // 已结束兜底（B 方案）：vote_model.dart 里没有任何结束字段（无结束
  // 时间、无结束状态、无 deadline/expire 类字段），所以不在渲染前凭
  // 日期推测结束态；只在一次提交返回“已结束”类服务端原话后，才把
  // 本卡标记为已结束。卡片级状态，不跨重启持久化；首次提交仍会
  // 失败一次，之后不再让用户反复提交同一张已结束的票。
  bool _ended = false;

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
    if (_ended || _busy || _selected.isEmpty) return;
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
    // 失败分支的已结束判定需要原始响应体，所以把它存下来。
    Response<dynamic>? submittedResponse;
    try {
      final response = await NetworkRepo.postVote(
        feedId: widget.data.id,
        optionIds: _selected.toList(),
        anonymous: _anonymous,
      );
      submittedResponse = response;
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
        // Dio 在非 2xx 时可能直接抛错而不返回 Response，此时若
        // 异常上还挂着响应体，已结束判定同样用它来判断。
        if (e is DioException) submittedResponse ??= e.response;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiFailure.fromError(e).message)),
        );
        // 已结束兜底：只认服务端原话 message 里含“已结束”（实测
        // 原话为“该投票已结束”），不凭 status/code 单独判定，避免把
        // 其他 -1 类业务失败误标为已结束。标记后立即清掉勾选，后续
        // 渲染走已结束表现，不再发 createUserVote 请求。
        if (_responseIndicatesEnded(submittedResponse)) {
          setState(() {
            _ended = true;
            _selected.clear();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 已结束判定共用的响应体解析：Map 直接转，JSON 字符串尝试解码，
  // 其他类型返回 null（不读 status/code/messageStatus）。
  Map<String, dynamic>? _responseBodyMap(dynamic body) {
    if (body is Map) {
      return body.map((key, value) => MapEntry('$key', value));
    }
    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry('$key', value));
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  // 已结束兜底判定：只看原始响应体 message 字段是否含“已结束”。
  // 不读 status/code/messageStatus，不读日期，不做任何启发式推测。
  bool _responseIndicatesEnded(Response<dynamic>? response) {
    final bodyMap = _responseBodyMap(response?.data);
    final message = bodyMap?['message'];
    return message != null && '$message'.contains('已结束');
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
              Text(
                _ended
                    ? '投票（已结束）'
                    : _voted
                        ? '投票（已投票）'
                        : '投票',
              ),
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
              child: _voted || _ended
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
          if (_ended) ...[
            Row(
              children: const [
                Spacer(),
                FilledButton(
                  onPressed: null,
                  child: Text('已结束'),
                ),
              ],
            ),
          ],
          if (!_voted && !_ended) ...[
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
          ],
        ],
      ),
    );
  }
}

// 供 FeedCard 复用的判定：有 vote 原始对象即尝试渲染。
bool hasVoteData(Datum data) => data.vote != null && data.vote!.isNotEmpty;
