import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../logic/model/login/login_response.dart';
import '../../logic/model/oss_upload/oss_upload_model.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/oss/aliyunoss_client.dart';
import '../../utils/oss/aliyunoss_config.dart';
import '../../utils/oss_util.dart';

/// 发文章编辑器，B 层参考级。
///
/// 未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码：长文章
/// 没有独立接口，就是同一条 POST /v6/feed/createFeed，图文模式
/// 加 is_html_article=1 + message_title（必填）+ message_cover
/// （题图，第一张上传图）。其余键与普通动态相同，走现有
/// postCreateFeed 传输层，不改普通动态的入参。图片上传复用
/// ReplyPage 的 OSS 流程。首次提交即当探针：失败时只显示
/// 服务端/网络提示，不回滚编辑器内容（用户可改后重发）。
class ArticleEditorPage extends StatefulWidget {
  const ArticleEditorPage({super.key});

  @override
  State<ArticleEditorPage> createState() => _ArticleEditorPageState();
}

class _ArticleEditorPageState extends State<ArticleEditorPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _imagePaths = <String>[];
  final _modelList = <OssUploadModel>[];
  bool _publishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage(limit: 9);
    if (picked.isEmpty) return;
    try {
      for (var i = 0; i < picked.length; i++) {
        if (_imagePaths.length >= 9) {
          SmartDialog.showToast('最多选择9张图片');
          break;
        }
        final imageBytes = await picked[i].readAsBytes();
        final image = await decodeImageFromList(imageBytes);
        final mimeType =
            lookupMimeType(picked[i].path) ?? 'image/png';
        final name =
            '${const Uuid().v1().replaceAll('-', '')}.${mimeType.replaceFirst('image/', '')}';
        _modelList.add(OssUploadModel(
          name: name,
          resolution: '${image.width}x${image.height}',
          md5: md5.convert(imageBytes).toString(),
        ));
        _imagePaths.add(picked[i].path);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiFailure.fromError(e).message)),
        );
      }
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文章标题不能为空')),
      );
      return;
    }
    if (!GlobalData().isLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先登录'),
          action: SnackBarAction(
            label: '登录',
            onPressed: () => Get.toNamed('/login'),
          ),
        ),
      );
      return;
    }
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      var pic = '';
      if (_imagePaths.isNotEmpty) {
        final data = await OssUtil.onPostOSSUploadPrepare(
          'image',
          'feed',
          _modelList,
        );
        if (data != null) {
          pic = data.fileInfo!
              .map((item) =>
                  '${data.uploadPrepareInfo!.uploadImagePrefix}/${item.uploadFileName}')
              .toList()
              .join(',');
          final client = AliyunOssClient(
            accessKeyId: data.uploadPrepareInfo!.accessKeyId!,
            accessKeySecret: data.uploadPrepareInfo!.accessKeySecret!,
            securityToken: data.uploadPrepareInfo!.securityToken!,
          );
          final config = AliyunOssConfig(
            endpoint: data.uploadPrepareInfo!.endPoint!,
            bucket: data.uploadPrepareInfo!.bucket!,
            directory: 'feed',
          );
          for (var i = 0; i < data.fileInfo!.length; i++) {
            SmartDialog.showLoading(msg: '正在上传图片 $i/${data.fileInfo!.length}');
            final result = await client.upload(
              id: i.toString(),
              config: config,
              ossFileName:
                  data.fileInfo![i].uploadFileName!.replaceFirst('feed', ''),
              filePath: _imagePaths[i],
            );
            if (result.state == AliyunOssResultState.fail) {
              SmartDialog.dismiss();
              SmartDialog.showToast('第 $i 张图片上传失败，请稍后重试');
              return;
            }
          }
          SmartDialog.dismiss();
        }
      }
      SmartDialog.showLoading(msg: '正在发布文章');
      final response = await NetworkRepo.postCreateFeed(
        FormData.fromMap({
          'type': 'feed',
          'message': _bodyController.text,
          'status': 1,
          'pic': pic,
          // B 层参考级：图文长文章模式，未实测，首次提交即当探针。
          'is_html_article': 1,
          'message_title': title,
          'message_cover': pic.isEmpty ? '' : pic.split(',').first,
        }),
      );
      SmartDialog.dismiss();
      if (response.data is! Map ||
          response.data['messageStatus'] != 'err_request_captcha') {
        readApiObject(response);
      }
      final data = LoginResponse.fromJson(response.data);
      if (!data.message.isNullOrEmpty) {
        SmartDialog.showToast(data.message!);
      } else if (data.data != null) {
        SmartDialog.showToast('发布成功');
        Get.back();
      }
    } catch (e) {
      SmartDialog.dismiss();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiFailure.fromError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发文章'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '文章标题（必填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '文章正文（长文）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.image),
                  label: const Text('添加图片'),
                ),
                for (final path in _imagePaths)
                  Chip(
                    label: Text(path.split('/').last),
                    onDeleted: () {
                      final index = _imagePaths.indexOf(path);
                      setState(() {
                        _imagePaths.remove(path);
                        if (index >= 0 && index < _modelList.length) {
                          _modelList.removeAt(index);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '长文章走 createFeed 图文模式（is_html_article=1），接口为未实测参考，首次提交即当探针；失败时请报提示。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _publishing ? null : _submit,
              child: Text(_publishing ? '发布中…' : '发布文章'),
            ),
          ],
        ),
      ),
    );
  }
}
