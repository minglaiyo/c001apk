// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Data _$DataFromJson(Map<String, dynamic> json) => Data(
      uid: json['uid'] as String?,
      username: json['username'] as String?,
      token: json['token'] as String?,
      notifyCount: json['notifyCount'] == null
          ? null
          : NotifyCount.fromJson(json['notifyCount'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DataToJson(Data instance) => <String, dynamic>{
      'uid': instance.uid,
      'username': instance.username,
      'token': instance.token,
      'notifyCount': instance.notifyCount,
    };
