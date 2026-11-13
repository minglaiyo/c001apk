import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../logic/network/api_failure.dart';
import '../logic/network/network_repo.dart';
import '../utils/extensions.dart';
import '../utils/utils.dart';

/// From Pilipala
class DownloadUtils {
  // 获取存储权限
  static Future<bool> requestStoragePer() async {
    await Permission.storage.request();
    PermissionStatus status = await Permission.storage.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      SmartDialog.show(
        useSystem: true,
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('存储权限未授权'),
            actions: [
              TextButton(
                onPressed: () async {
                  openAppSettings();
                },
                child: const Text('去授权'),
              )
            ],
          );
        },
      );
      return false;
    } else {
      return true;
    }
  }

  // 获取相册权限
  static Future<bool> requestPhotoPer() async {
    await Permission.photos.request();
    PermissionStatus status = await Permission.photos.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      SmartDialog.show(
        useSystem: true,
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('相册权限未授权'),
            actions: [
              TextButton(
                onPressed: () async {
                  openAppSettings();
                },
                child: const Text('去授权'),
              )
            ],
          );
        },
      );
      return false;
    } else {
      return true;
    }
  }

  static Future<void> downloadImg(List<String> urlList) async {
    if (Platform.isWindows || Platform.isLinux) {
      SmartDialog.showToast('当前平台暂不支持直接保存图片，请在浏览器中保存');
      return;
    }
    try {
      if (Platform.isAndroid &&
          (await DeviceInfoPlugin().androidInfo).version.sdkInt <= 32) {
        if (!await requestStoragePer()) {
          return;
        }
      } else {
        if (!await requestPhotoPer()) {
          return;
        }
      }
      SmartDialog.showLoading(msg: '保存中');
      Dio dio = Dio();
      for (int index = 0; index < urlList.length; index++) {
        final Response response = await dio.get(urlList[index],
            options: Options(responseType: ResponseType.bytes));
        final String picName = urlList[index].split('/').last;
        final SaveResult result = await SaverGallery.saveImage(
          Uint8List.fromList(response.data),
          name: picName,
          androidRelativePath: "Pictures/c001apk",
          androidExistNotSave: true,
        );
        if (result.errorMessage != null) {
          SmartDialog.dismiss();
          SmartDialog.showToast('第 ${index + 1} 张图片保存失败，请检查存储权限');
        }
        if (index == urlList.length - 1) {
          SmartDialog.dismiss();
          if (result.isSuccess) {
            SmartDialog.showToast('已保存');
          }
        }
      }
    } catch (err) {
      SmartDialog.dismiss();
      SmartDialog.showToast('图片保存失败，请检查网络或存储权限');
    }
  }
}

/// 获取应用安装包下载地址并交给原生/浏览器下载。
Future<String?> onGetDownloadUrl(
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

/// 复制下载地址后交给系统处理；Android 走原生下载通道。
void onDownloadFile(String url, String name) async {
  Clipboard.setData(ClipboardData(text: url));
  if (Platform.isAndroid) {
    if (!await const MethodChannel('samples.flutter.dev/channel')
        .invokeMethod(
      'downloadApk',
      {
        'url': url,
        'name': name,
      },
    )) {
      Utils.launchURL(url);
    }
  } else {
    launchUrl(Uri.parse(url));
  }
}
