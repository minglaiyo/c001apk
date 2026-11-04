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
///
/// TODO: vote debug probe —— 投票失败时额外弹出“投票失败详情”对话框，
/// 原样展示服务端 message / status / code 与本次提交参数，用于区分
/// “选项 id 语义错”与“账号/状态类限制”。根因确认后移除本探针，或
/// 改为只显示服务端 message 的正式行为。探针只在失败时出现，成功
/// 路径不动；全局 api_failure.dart 的“只进安全本地文案”规则不动，
/// 本探针只在投票链路内读取 postVote 已返回的原始响应体。
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
    // TODO: vote debug probe —— 失败时对话框要展示本次提交参数，
    // 所以提交前先把实际发出的参数快照下来。
    final submittedOptionIds = _selected.toList();
    final submittedAnonymous = _anonymous;
    Response<dynamic>? submittedResponse;
    try {
      final response = await NetworkRepo.postVote(
        feedId: widget.data.id,
        optionIds: submittedOptionIds,
        anonymous: submittedAnonymous,
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
        // 异常上还挂着响应体，探针对话框同样把它展示出来。
        if (e is DioException) submittedResponse ??= e.response;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiFailure.fromError(e).message)),
        );
        // TODO: vote debug probe —— 通用提示之外，额外弹一次详情
        // 对话框，原样展示服务端 message / status / code 与提交参数。
        // 成功路径不走这里，所以成功时不会多弹任何调试信息。
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('投票失败详情（调试探针）'),
            content: SingleChildScrollView(
              child: SelectableText(
                _voteFailureProbeText(
                  failure: ApiFailure.fromError(e),
                  response: submittedResponse,
                  feedId: widget.data.id,
                  optionIds: submittedOptionIds,
                  anonymous: submittedAnonymous,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // TODO: vote debug probe —— 只在投票失败时调用。原始响应体来自
  // postVote 已返回的 Response，不经过全局 ApiFailure 文案过滤；
  // message 一律原样展示（不翻译、不改写），字段缺失时明确写“（无）”
  // 而不是留空，避免截图时分不清“空值”与“没展示”。
  String _voteFailureProbeText({
    required ApiFailure failure,
    required Response<dynamic>? response,
    required dynamic feedId,
    required List<String> optionIds,
    required bool anonymous,
  }) {
    final lines = <String>[
      '本对话框仅为调试探针，待根因确认后移除。',
      '',
      '客户端通用提示：${failure.message}',
      '',
      '接口：POST /v6/vote/createUserVote',
      'HTTP 状态：${response?.statusCode ?? '（无响应，未到达服务端或未返回）'}',
    ];
    final body = response?.data;
    final bodyMap = _voteProbeBodyMap(body);
    if (bodyMap != null) {
      lines
        ..add('')
        ..add('服务端原话 message：${_voteProbeField(bodyMap['message'])}')
        ..add('messageStatus：${_voteProbeField(bodyMap['messageStatus'])}')
        ..add('code：${_voteProbeField(bodyMap['code'])}')
        ..add('status：${_voteProbeField(bodyMap['status'])}')
        ..add('error：${_voteProbeField(bodyMap['error'])}');
      final data = bodyMap['data'];
      if (data != null) {
        final dataText = data.toString();
        lines.add(
          dataText.length > 1000
              ? 'data（摘要，前 1000 字，共 ${dataText.length} 字）：${dataText.substring(0, 1000)}'
              : 'data：$dataText',
        );
      } else {
        lines.add('data：（无）');
      }
    } else if (body is String) {
      // 非 JSON 文本体（例如微页面回了 HTML）：不全文塞进对话框，
      // 只放前 4000 字并注明总长度，避免超大体撑爆弹窗。
      lines
        ..add('')
        ..add('响应体不是 JSON，原文前 4000 字（共 ${body.length} 字）：')
        ..add(body.length > 4000 ? body.substring(0, 4000) : body);
    } else if (body == null) {
      lines
        ..add('')
        ..add('响应体：（无）');
    } else {
      lines
        ..add('')
        ..add('响应体类型：${body.runtimeType}');
    }
    lines
      ..add('')
      ..add('本次提交参数：')
      ..add('  id = $feedId')
      ..add('  anonymous_status = ${anonymous ? 1 : 0}');
    if (optionIds.isEmpty) {
      lines.add('  select_option = （空）');
    } else {
      for (var i = 0; i < optionIds.length; i++) {
        lines.add('  select_option[$i] = ${optionIds[i]}');
      }
    }
    return lines.join('\n');
  }

  Map<String, dynamic>? _voteProbeBodyMap(dynamic body) {
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

  String _voteProbeField(dynamic value) {
    if (value == null) return '（无）';
    final text = '$value';
    return text.isEmpty ? '（空）' : text;
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
              // TODO: vote debug probe —— 失败时会额外弹出详情对话框。
              '投票接口为未实测参考，首次提交即当探针；失败时会弹出服务端原话详情。',
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
