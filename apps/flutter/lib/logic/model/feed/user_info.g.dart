// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) => UserInfo(
      uid: (json['uid'] as num?)?.toInt(),
      username: json['username'] as String?,
      follow: (json['follow'] as num?)?.toInt(),
      fans: (json['fans'] as num?)?.toInt(),
      userAvatar: json['userAvatar'] as String?,
    );

Map<String, dynamic> _$UserInfoToJson(UserInfo instance) => <String, dynamic>{
      'uid': instance.uid,
      'username': instance.username,
      'follow': instance.follow,
      'fans': instance.fans,
      'userAvatar': instance.userAvatar,
    };
