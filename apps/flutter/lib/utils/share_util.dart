import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'html_text_util.dart';

/// 分享文本的实体类型。
enum ShareType { feed, u, apk, t, product }

/// 举报对象类型。
// ignore: constant_identifier_names
enum ReportType { Feed, Reply, User }

/// 按产品规范生成四行分享文本：标题、Coolapk1s 链接、Coolapk 链接、署名。
String getShareUrl(String id, ShareType type) {
  return 'https://www.coolapk1s.com/${type.name}/${Uri.encodeComponent(id)}';
}

String getShareText(String id, ShareType type,
    {String? title, String? message}) {
  String plain(String value) =>
      parseHtmlString(value).replaceAll(RegExp(r'\s+'), ' ').trim();
  var name = plain(title ?? '');
  if (name.isEmpty) name = plain(message ?? '');
  if (name.isEmpty) {
    name = switch (type) {
      ShareType.feed => '动态',
      ShareType.u => '用户',
      ShareType.apk => '应用',
      ShareType.t => '话题',
      ShareType.product => '数码',
    };
  }
  // A normal feed has no article title; keep its summary on one short line.
  if (name.runes.length > 100) {
    name = '${String.fromCharCodes(name.runes.take(100))}…';
  }
  return '$name\n${getShareUrl(id, type)}\n'
      'https://www.coolapk.com/${type.name}/${Uri.encodeComponent(id)}\n'
      '分享自c001apk';
}

/// Windows 直接复制完整内容，其他平台走系统分享。
Future<void> shareContent(String id, ShareType type,
    {String? title, String? message, required BuildContext context}) async {
  final text = getShareText(id, type, title: title, message: message);
  try {
    if (Platform.isWindows) {
      await Clipboard.setData(ClipboardData(text: text));
      SmartDialog.showToast('已复制');
    } else {
      final box = context.findRenderObject();
      await Share.share(text,
          sharePositionOrigin: box is RenderBox && box.hasSize
              ? box.localToGlobal(Offset.zero) & box.size
              : null);
    }
  } catch (_) {
    SmartDialog.showToast(Platform.isWindows ? '复制失败，请重试' : '分享失败，请重试');
  }
}

/// 打开举报页。
void report(dynamic id, ReportType reportType) {
  String c = reportType == ReportType.User ? 'user' : 'feed';
  String type = switch (reportType) {
    ReportType.Feed => '&type=feed',
    ReportType.Reply => '&type=feed_reply',
    ReportType.User => '',
  };
  Get.toNamed(
    '/webview',
    parameters: {
      'url': 'https://m.coolapk.com/mp/do?c=$c&m=report$type&id=$id',
    },
  );
}

/// 下载图片后调起系统分享。
Future<void> onShareImg(String url) async {
  SmartDialog.showLoading(msg: '正在加载');
  var response = await Dio()
      .get(url, options: Options(responseType: ResponseType.bytes));
  final temp = await getTemporaryDirectory();
  SmartDialog.dismiss();
  final String imgName = url.split('/').last;
  var path = '${temp.path}/$imgName';
  File(path).writeAsBytesSync(response.data);
  Share.shareXFiles([XFile(path)], subject: url);
}
