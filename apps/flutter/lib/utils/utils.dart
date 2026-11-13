import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

import '../constants/constants.dart';
import '../logic/network/network_repo.dart';
import '../logic/network/api_failure.dart';
import '../pages/ffflist/ffflist_page.dart' show FFFListType;
import '../utils/extensions.dart';
import '../utils/storage_util.dart';
import '../components/feed_navigation.dart';

// ignore: constant_identifier_names
enum ReportType { Feed, Reply, User }

enum ShareType { feed, u, apk, t, product }

class Utils {
  static const platform = MethodChannel('samples.flutter.dev/channel');

  static bool isDesktop =
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  static String getFollowTitle(int index) {
    return switch (index) {
      1 => '用户关注',
      2 => '话题关注',
      3 => '数码关注',
      4 => '应用关注',
      _ => '全部关注',
    };
  }

  static String getFollowUrl(int index) {
    String url = '/page?url=V9_HOME_TAB_FOLLOW';
    return switch (index) {
      1 => '$url&type=circle',
      2 => '$url&type=topic',
      3 => '$url&type=product',
      4 => '$url&type=apk',
      _ => url,
    };
  }

  static String getShareUrl(String id, ShareType type) {
    return 'https://www.coolapk1s.com/${type.name}/${Uri.encodeComponent(id)}';
  }

  static String getShareText(String id, ShareType type,
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

  static Future<void> shareContent(String id, ShareType type,
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

  static void report(dynamic id, ReportType reportType) {
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

  static bool isSupportWebview() {
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows;
  }

  static Future<void> onShareImg(String url) async {
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

  static void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    SmartDialog.showToast('已复制');
  }

  static List<double> getImageLp(String url) {
    double imgWidth = 1;
    double imgHeight = 1;
    int at = url.lastIndexOf("@");
    int x = url.lastIndexOf("x");
    int dot = url.lastIndexOf(".");
    if (at != -1 && x != -1 && dot != -1) {
      try {
        imgWidth = double.parse(url.substring(at + 1, x));
        imgHeight = double.parse(url.substring(x + 1, dot));
      } catch (e) {
        debugPrint(e.toString());
      }
    }
    return [imgWidth, imgHeight];
  }

  static Future<String?> onGetDownloadUrl(
    String appName,
    String packageName,
    int id,
    String versionName,
    int versionCode,
  ) async {
    try {
      await NetworkRepo.getAppDownloadUrl(
        packageName: packageName,
        id: id,
        versionCode: versionCode,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 302) {
        String? url = e.response?.headers['Location']?.firstOrNull;
        if (!url.isNullOrEmpty) {
          onDownloadFile(
            url!,
            '$appName-$versionName-$versionCode.apk',
          );
          return url;
        } else {
          SmartDialog.showToast('无法获取下载链接，请稍后重试');
        }
      } else {
        SmartDialog.showToast(ApiFailure.fromError(e).message);
      }
    }
    return null;
  }

  static void onDownloadFile(String url, String name) async {
    Clipboard.setData(ClipboardData(text: url));
    if (Platform.isAndroid) {
      if (!await platform.invokeMethod(
        'downloadApk',
        {
          'url': url,
          'name': name,
        },
      )) {
        Utils.launchURL(url);
      }
    } else {
      Utils.launchURL(url);
    }
  }

  static void onOpenLink(
    String url, [
    String? title,
    bool needConvert = false,
    BuildContext? context,
  ]) {
    try {
      _openLink(url, title, needConvert, context);
    } on FormatException {
      SmartDialog.showToast('暂不支持此链接');
    }
  }

  static void _openLink(
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
        onOpenLink(url, title, true, context);
      } else {
        if (url.startsWith(Constants.PREFIX_HTTP)) {
          if (isSupportWebview() && !GStorage.openInBrowser) {
            Get.toNamed('/webview', parameters: {'url': url});
          } else {
            launchURL(url);
          }
        } else {
          SmartDialog.showToast('暂不支持此链接');
        }
      }
    }
  }

  static final Random random = Random();

  static String parseHtmlString(String htmlString) {
    dom.Document document = html_parser.parse(htmlString);
    return _parseNode(document.body);
  }

  static String _parseNode(dom.Node? node) {
    if (node == null) {
      return '';
    }

    if (node is dom.Element) {
      if (node.localName == 'br') {
        return '\n';
      }
      return node.nodes.map(_parseNode).join('');
    } else if (node is dom.Text) {
      return node.text;
    }

    return '';
  }

  static launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri)) {
        SmartDialog.showToast('无法打开链接，请检查浏览器设置');
      }
    } catch (e) {
      SmartDialog.showToast('无法打开链接，请检查浏览器设置');
    }
  }

  static String appSign(
      Map<String, dynamic> params, String appkey, String appsec) {
    params['appkey'] = appkey;
    var searchParams = Uri(queryParameters: params).query;
    var sortedParams = searchParams.split('&')..sort();
    var sortedQueryString = sortedParams.join('&');

    var appsecString = sortedQueryString + appsec;
    var md5Digest = md5.convert(utf8.encode(appsecString));
    var md5String = md5Digest.toString(); // 获取MD5哈希值

    return md5String;
  }

  static List<int> generateRandomBytes(int minLength, int maxLength) {
    return List<int>.generate(random.nextInt(maxLength - minLength + 1),
        (_) => random.nextInt(0x60) + 0x20);
  }

  static String base64EncodeRandomString(int minLength, int maxLength) {
    List<int> randomBytes = generateRandomBytes(minLength, maxLength);
    return base64.encode(randomBytes);
  }
}
