/// 动态投票的宽容解析。
///
/// 未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码：卡片字段就是
/// Datum.vote 对象，提交是 POST /v6/vote/createUserVote。但 vote 对象
/// 内层键名未经登录实测，所以这里不假设任何确切键名：选项、票数、
/// 已投态全部多路兜底，读不到时 [VoteData.recognized] 为 false，
/// 卡片只显示“投票数据未识别”而不崩溃、不编造选项。
class VoteOption {
  const VoteOption({
    required this.id,
    required this.label,
    this.votes,
  });

  final String id;
  final String label;
  final int? votes;
}

class VoteData {
  const VoteData({
    required this.recognized,
    this.options = const [],
    this.votedOptionIds = const {},
    this.totalVotes,
    this.isMulti = false,
  });

  final bool recognized;
  final List<VoteOption> options;
  final Set<String> votedOptionIds;
  final int? totalVotes;

  /// 参考称提交字段是 select_option[0..n]（可多选），但单选/多选
  /// 未实测；卡片默认按多选复选框渲染，服务端以提交结果为准。
  final bool isMulti;
}

String _text(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

int? _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_text(value));
}

dynamic _first(Map map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null && _text(value).isNotEmpty) return value;
  }
  return null;
}

List<dynamic>? _optionList(Map map) {
  for (final key in const [
    'options',
    'optionList',
    'select_options',
    'selectOptions',
    'vote_options',
    'voteOptions',
    'items',
    'choices',
    'option',
  ]) {
    final value = map[key];
    if (value is List && value.isNotEmpty) return value;
  }
  return null;
}

VoteData parseVote(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) {
    return const VoteData(recognized: false);
  }
  final list = _optionList(raw);
  if (list == null) {
    return const VoteData(recognized: false);
  }
  final options = <VoteOption>[];
  for (final item in list) {
    if (item is! Map) continue;
    final id = _text(_first(item, [
      'id',
      'option_id',
      'optionId',
      'value',
      'key',
    ]));
    if (id.isEmpty) continue;
    final label = _text(_first(item, [
      'title',
      'text',
      'name',
      'label',
      'content',
      'option_title',
    ]));
    final votes = _toInt(_first(item, [
      'vote_num',
      'votes',
      'count',
      'num',
      'vote_count',
    ]));
    options.add(VoteOption(
      id: id,
      label: label.isEmpty ? '选项 $id' : label,
      votes: votes,
    ));
  }
  if (options.isEmpty) {
    return const VoteData(recognized: false);
  }
  final voted = <String>{};
  final votedRaw = raw['voted_options'] ??
      raw['selected_options'] ??
      raw['my_options'] ??
      raw['user_vote'] ??
      raw['voted'];
  if (votedRaw is List) {
    for (final item in votedRaw) {
      final id = item is Map
          ? _text(_first(item, ['id', 'option_id', 'optionId', 'value']))
          : _text(item);
      if (id.isNotEmpty) voted.add(id);
    }
  } else if (votedRaw is Map) {
    final id = _text(_first(votedRaw, ['id', 'option_id', 'optionId']));
    if (id.isNotEmpty) voted.add(id);
  }
  // 已投态只用顶层标记为准；单项标记因原始 Map 已丢弃不回填。
  final total = _toInt(_first(raw, [
    'total_num',
    'total_votes',
    'vote_num',
    'total',
  ]));
  final multiRaw = raw['is_multi'] ?? raw['multi'] ?? raw['allow_multi'];
  final isMulti = multiRaw is bool
      ? multiRaw
      : multiRaw is num
          ? multiRaw != 0
          : _text(multiRaw) == '1' || _text(multiRaw) == 'true';
  return VoteData(
    recognized: true,
    options: options,
    votedOptionIds: voted,
    totalVotes: total,
    isMulti: isMulti,
  );
}
