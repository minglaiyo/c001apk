// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'datum.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Datum _$DatumFromJson(Map<String, dynamic> json) => Datum(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] as String?,
      logo: json['logo'] as String?,
      apkversionname: json['apkversionname'] as String?,
      apkversioncode: (json['apkversioncode'] as num?)?.toInt(),
      apksize: json['apksize'] as String?,
      lastupdate: (json['lastupdate'] as num?)?.toInt(),
      packageName: json['packageName'] as String?,
      changelog: json['changelog'] as String?,
      pkgBitType: (json['pkg_bit_type'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DatumToJson(Datum instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'logo': instance.logo,
      'apkversionname': instance.apkversionname,
      'apkversioncode': instance.apkversioncode,
      'apksize': instance.apksize,
      'lastupdate': instance.lastupdate,
      'packageName': instance.packageName,
      'changelog': instance.changelog,
      'pkg_bit_type': instance.pkgBitType,
    };
