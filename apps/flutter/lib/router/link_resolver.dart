import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../components/feed_navigation.dart';
import '../constants/constants.dart';
import '../pages/ffflist/ffflist_page.dart' show FFFListType;
import '../utils/extensions.dart';
import '../utils/storage_util.dart';
import '../utils/utils.dart';

/// 酷安链接与站内路径到应用路由的唯一映射入口。
///
/// 路由知识集中在 router 层（与 app_pages.dart 对齐），
/// 供深链、正文链接、分享卡片等所有入口使用。
void openLink(
  String url, [
  String? title,
  bool needConvert = false,
  BuildContext? context,
]) {
  try {
    _resolve(url, title, needConvert, context);
  } on FormatException {
    SmartDialog.showToast('暂不支持此链接');
  }
}

void _resolve(
  String url, [
  String? title,
  bool needConvert = false,
  BuildContext? context,
]) {
  if (url.isEmpty) {
    return;
  }
  String path = url;
  if (needConvert) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      SmartDialog.showToast('暂不支持此链接');
      return;
    }
    const hosts = {
      'coolapk.com',
      'www.coolapk.com',
      'm.coolapk.com',
      'coolapk1s.com',
      'www.coolapk1s.com',
    };
    if (uri.scheme == 'coolmarket') {
      path = hosts.contains(uri.host) || uri.host == 'com.coolapk.market'
          ? uri.path
          : '/${uri.host}${uri.path}';
      if (uri.hasQuery) path += '?${uri.query}';
    } else if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        hosts.contains(uri.host)) {
      path = uri.path;
      if (uri.hasQuery) path += '?${uri.query}';
    }
  }
  if (path.startsWith('/')) {
    final segments = Uri.parse(path).pathSegments;
    if (segments.isNotEmpty &&
        const {'feed', 'event', 'u', 'apk', 'game', 't', 'product'}
            .contains(segments.first) &&
        (segments.length < 2 || segments[1].trim().isEmpty)) {
      SmartDialog.showToast('暂不支持此链接');
      return;
    }
  }
  if (RegExp(r'^/feed/[0-9]+/?(?:[?#]|$)').hasMatch(path)) {
    // Share queries and fragments are not part of the feed identifier.
    final id = Uri.parse(path).pathSegments[1];
    if (context != null) {
      FeedNavigation.open(context, id);
    } else {
      Get.toNamed('/feed/$id');
    }
  } else if (RegExp(r'^/event/[0-9]+(?:[?#]|$)').hasMatch(path)) {
    final id = Uri.parse(path).path.substring('/event/'.length);
    Get.toNamed('/event/$id');
  } else if (path.startsWith(Constants.PREFIX_USER)) {
    String uid = Uri.parse(path).pathSegments.skip(1).join('/');
    try {
      uid = Uri.encodeComponent(uid);
    } catch (e) {
      debugPrint(e.toString());
    }
    Get.toNamed('/u/$uid');
  } else if (path.startsWith(Constants.PREFIX_APP)) {
    Get.toNamed(
        '/apk/${Uri.encodeComponent(Uri.parse(path).pathSegments[1])}');
  } else if (path.startsWith(Constants.PREFIX_GAME)) {
    Get.toNamed(
        '/apk/${Uri.encodeComponent(Uri.parse(path).pathSegments[1])}');
  } else if (path.startsWith(Constants.PREFIX_TOPIC)) {
    String tag = Uri.parse(path).pathSegments.skip(1).join('/');
    try {
      tag = Uri.encodeComponent(tag);
    } catch (e) {
      debugPrint(e.toString());
    }
    if (Uri.parse(path).queryParameters['type'] == '8') {
      Get.toNamed('/coolpic', parameters: {'title': tag});
    } else {
      Get.toNamed('/t/$tag');
    }
  } else if (path.startsWith(Constants.PREFIX_PRODUCT)) {
    Get.toNamed(
        '/product/${Uri.encodeComponent(Uri.parse(path).pathSegments[1])}');
  } else if (path.startsWith(Constants.PREFIX_CAROUSEL)) {
    Get.toNamed(
      '/carousel',
      parameters: {
        'url': path.replaceFirst(Constants.PREFIX_CAROUSEL, ''),
        'title': title.orEmpty,
        'isInit': '1',
      },
    );
  } else if (path.startsWith(Constants.PREFIX_CAROUSEL1)) {
    Get.toNamed(
      '/carousel',
      parameters: {
        'url': path.replaceFirst('#', ''),
        'title': title.orEmpty,
        'isInit': '1',
      },
    );
  } else if (path.startsWith(Constants.PREFIX_USER_LIST)) {
    Get.toNamed(
      '/ffflist',
      arguments: {
        'type': FFFListType.USER_FOLLOW,
      },
    );
  } else if (path.startsWith(Constants.PREFIX_DYH)) {
    Get.toNamed(
      '/dyh',
      parameters: {
        'id': path.replaceFirst(Constants.PREFIX_DYH, ''),
        'title': title.orEmpty,
      },
    );
  } else {
    if (!needConvert) {
      openLink(url, title, true, context);
    } else {
      if (url.startsWith(Constants.PREFIX_HTTP)) {
        if (!GStorage.openInBrowser) {
          Get.toNamed('/webview', parameters: {'url': url});
        } else {
          Utils.launchURL(url);
        }
      } else {
        SmartDialog.showToast('暂不支持此链接');
      }
    }
  }
}
