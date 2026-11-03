import 'package:json_annotation/json_annotation.dart';

part 'entity.g.dart';

@JsonSerializable()
class Entity {
  String? entityType;
  String? title;
  String? url;
  String? pic;
  String? logo;
  String? userAvatar;
  String? username;

  /// 热度数值，B 层参考级：服务端字段未实测，宽容读
  /// hot_num / commentnum / comment_num 兜底；都没有时为 null，
  /// 排序按钮置灰，不发明服务端排序参数。
  dynamic hotNum;

  Entity({
    this.entityType,
    this.title,
    this.url,
    this.pic,
    this.logo,
    this.userAvatar,
    this.username,
    this.hotNum,
  });

  factory Entity.fromJson(Map<String, dynamic> json) {
    return _$EntityFromJson(json);
  }

  Map<String, dynamic> toJson() => _$EntityToJson(this);
}
