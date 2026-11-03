// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Entity _$EntityFromJson(Map<String, dynamic> json) => Entity(
      entityType: json['entityType'] as String?,
      title: json['title']?.toString(),
      url: json['url'] as String?,
      pic: json['pic'] as String?,
      logo: json['logo'] as String?,
      userAvatar: json['userAvatar'] as String?,
      username: json['username'] as String?,
      // 手工同步：本地无 build_runner，热度字段多路兜底。
      hotNum: json['hot_num'] ?? json['commentnum'] ?? json['comment_num'],
    );

Map<String, dynamic> _$EntityToJson(Entity instance) => <String, dynamic>{
      'entityType': instance.entityType,
      'title': instance.title,
      'url': instance.url,
      'pic': instance.pic,
      'logo': instance.logo,
      'userAvatar': instance.userAvatar,
      'username': instance.username,
      'hot_num': instance.hotNum,
    };
