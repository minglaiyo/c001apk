import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart' hide Response, FormData;

import '../model/login/login_response.dart';
import '../model/oss_upload/datum.dart';
import '../model/oss_upload/oss_upload_model.dart';
import '../network/api_failure.dart';
import '../network/network_repo.dart';
import '../../utils/oss/aliyunoss_client.dart';
import '../../utils/oss/aliyunoss_config.dart';
import '../../utils/oss_util.dart';
import '../../utils/extensions.dart';

/// 动态/回复发布流程的唯一实现。
///
/// 两处发布入口（feed 详情的 ReplyPage 与通用 ReplyDialog）共用：
/// 图片 OSS 上传、发布请求的信封校验、验证码挑战与验证通过后的重发。
/// 请求参数由调用方闭包组装——两种目标形态（发动态/发回复）的
/// 字段差异保留在各自入口，加载提示与响应处理在此统一。
class ReplyPublisher {
  ReplyPublisher({
    required bool Function() isMounted,
    required BuildContext Function() context,
  })  : _isMounted = isMounted,
        _context = context;

  final bool Function() _isMounted;
  final BuildContext Function() _context;

  final captchaController = TextEditingController();

  Future<Response> Function()? _request;
  String? _successMessage;
  bool _withResult = false;

  /// 上传待发布图片并返回 `pic` 字段值；无图片时返回空串。
  ///
  /// 上传准备失败时按原流程静默继续（返回空串）；单张上传失败时
  /// 完成提示并返回 null，调用方应中止发布。
  Future<String?> uploadFeedImages({
    required List<String> filePaths,
    required List<OssUploadModel> modelList,
  }) async {
    if (filePaths.isEmpty) return '';
    OssDatum? data =
        await OssUtil.onPostOSSUploadPrepare('image', 'feed', modelList);
    if (data == null) return '';
    final pic = data.fileInfo!
        .map((item) =>
            '${data.uploadPrepareInfo!.uploadImagePrefix}/${item.uploadFileName}')
        .toList()
        .join(',');
    AliyunOssClient client = AliyunOssClient(
      accessKeyId: data.uploadPrepareInfo!.accessKeyId!,
      accessKeySecret: data.uploadPrepareInfo!.accessKeySecret!,
      securityToken: data.uploadPrepareInfo!.securityToken!,
    );
    AliyunOssConfig config = AliyunOssConfig(
      endpoint: data.uploadPrepareInfo!.endPoint!,
      bucket: data.uploadPrepareInfo!.bucket!,
      directory: "feed",
    );
    for (int i = 0; i < data.fileInfo!.length; i++) {
      SmartDialog.showLoading(msg: '正在上传图片 $i/${data.fileInfo!.length}');
      AliyunOssResult result = await client.upload(
        id: i.toString(),
        config: config,
        ossFileName:
            data.fileInfo![i].uploadFileName!.replaceFirst('feed', ''),
        filePath: filePaths[i],
      );
      if (result.state == AliyunOssResultState.fail) {
        SmartDialog.dismiss();
        SmartDialog.showToast('第 $i 张图片上传失败，请稍后重试');
        return null;
      }
    }
    return pic;
  }

  /// 执行一次发布。[successMessage] 为 null 时不弹成功提示。
  /// [withResult] 为 true 时以 `{'data': ...}` 回传给上一个页面。
  Future<void> publish(
    Future<Response> Function() request, {
    String? successMessage,
    bool withResult = false,
  }) {
    _request = request;
    _successMessage = successMessage;
    _withResult = withResult;
    return _send();
  }

  Future<void> _send() async {
    try {
      SmartDialog.showLoading(msg: '正在发布');
      Response response = await _request!();
      if (response.data is! Map ||
          response.data['messageStatus'] != 'err_request_captcha') {
        readApiObject(response);
      }
      LoginResponse data = LoginResponse.fromJson(response.data);
      if (!data.message.isNullOrEmpty) {
        SmartDialog.dismiss();
        SmartDialog.showToast(data.message!);
        if (data.messageStatus == 'err_request_captcha') {
          _getCaptcha();
        }
      } else if (data.data != null) {
        SmartDialog.dismiss();
        if (_successMessage != null) {
          SmartDialog.showToast(_successMessage!);
        }
        Get.back(result: _withResult ? {'data': data.data} : null);
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(ApiFailure.fromError(e).message);
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  Future<void> _getCaptcha() async {
    try {
      Response response = await NetworkRepo.getValidateCaptcha();
      if (_isMounted()) {
        captchaController.clear();
        showDialog(
          context: _context(),
          builder: (context) => AlertDialog(
            title: const Text('验证码'),
            content: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Image.memory(response.data),
                  ),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: captchaController,
                      autofocus: true,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(4),
                        FilteringTextInputFormatter.allow(
                            RegExp("[0-9a-zA-Z]")),
                      ],
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        filled: true,
                        labelText: '验证码',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Get.back();
                  _postRequestValidate();
                },
                child: const Text('验证并继续'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      SmartDialog.showToast('无法获取验证码：${ApiFailure.fromError(e).message}');
      debugPrint(e.toString());
    }
  }

  Future<void> _postRequestValidate() async {
    try {
      Response response = await NetworkRepo.postRequestValidate(
        FormData.fromMap({
          'type': 'err_request_captcha',
          'code': captchaController.text,
        }),
      );
      LoginResponse data = LoginResponse.fromJson(response.data);
      if (data.data == '验证通过') {
        _send();
      } else if (!data.message.isNullOrEmpty) {
        SmartDialog.showToast(data.message!);
        if (data.message == '请输入正确的图形验证码') {
          _getCaptcha();
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void dispose() {
    captchaController.dispose();
  }
}
