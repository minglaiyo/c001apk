import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/network_image.dart';
import '../../constants/app_sizes.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/model/oss_upload/oss_upload_model.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/oss/aliyunoss_client.dart';
import '../../utils/oss/aliyunoss_config.dart';
import '../../utils/oss_util.dart';

/// 编辑资料（个人主页）。
///
/// 接口口径与「点一下存一下」的交互均来自 c001apk_next 的抓包 + 实测核对
/// （2026-09-24，见 docs/REFACTOR_NOTES.md）：
/// - 性别 / 生日 / 地区 / 签名走 `POST /v6/account/changeProfile`（key + value），
///   成功响应 `{"data":{...完整资料...}}` 不带 message，失败一定带 message；
/// - 生日 / 地区设回保密走 `POST /v6/account/resetProfile`（key=birth / location）；
/// - 头像走 `POST /v6/account/changeAvatar`（multipart，字段 imgFile，
///   filename 用图片 md5 且不带扩展名），返回新头像地址；
/// - 背景图先 OSS 上传（uploadBucket=avatar & uploadDir=cover），
///   再 `POST /v6/account/changeAvatarCover` 回传完整 CDN 地址。
/// 官方还有「预置背景图」（GET /v6/account/avatarCoverList），暂不移植。
///
/// 官方的头像/背景图裁剪页依赖原生裁剪组件，记入未移植项；此处直传原图。
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  Datum? _profile;
  bool _loading = true;
  String? _error;
  int _gender = -1;
  int _year = 2000;
  int _month = 1;
  int _day = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = await NetworkRepo.getDataFromUrl(
        url: '/v6/user/space?uid=${GlobalData().uid}');
    if (!mounted) return;
    if (state is Success) {
      setState(() {
        _profile = state.response! as Datum;
        _loading = false;
      });
      _syncFormFromProfile();
    } else {
      setState(() {
        _error = state is Error ? state.errMsg : '加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  void _syncFormFromProfile() {
    final data = _profile;
    if (data == null) return;
    _bioController.text = data.bio ?? '';
    _provinceController.text = data.province ?? '';
    _cityController.text = data.city ?? '';
    _gender = int.tryParse('${data.gender ?? -1}') ?? -1;
    final year = int.tryParse('${data.birthyear}') ?? 0;
    if (year > 0) {
      _year = year;
      _month = int.tryParse('${data.birthmonth}') ?? 1;
      _day = int.tryParse('${data.birthday}') ?? 1;
    }
  }

  /// 统一执行一次资料修改；readApiObject 会在服务端返回 message 时抛出，
  /// 成功（{"data":...} 不带 message）时把返回的完整资料写回本地回显。
  Future<bool> _run(Future<dynamic> Function() action) async {
    SmartDialog.showLoading(msg: '正在保存');
    try {
      final response = await action();
      final body = readApiObject(response);
      if (mounted && body['data'] is Map) {
        setState(() {
          _profile = Datum.fromJson((body['data'] as Map).cast<String, dynamic>());
        });
        _syncFormFromProfile();
      }
      SmartDialog.dismiss();
      return true;
    } catch (error) {
      SmartDialog.dismiss();
      SmartDialog.showToast(ApiFailure.fromError(error).message);
      return false;
    }
  }

  Future<void> _saveField(String key, String value) async {
    final ok =
        await _run(() => NetworkRepo.postChangeProfile(key: key, value: value));
    if (ok && mounted) SmartDialog.showToast('已保存');
  }

  Future<void> _resetField(String key) async {
    final ok = await _run(() => NetworkRepo.postResetProfile(key: key));
    if (ok && mounted) {
      SmartDialog.showToast(key == 'birth' ? '生日已设为保密' : '地区已设为保密');
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      SmartDialog.showToast('读取图片失败');
      return;
    }
    // 官方口径：part 名 imgFile，filename 用图片 md5 且不带扩展名，
    // Content-Type image/jpeg；成功返回新头像地址。
    final md5Hex = md5.convert(bytes).toString();
    final file = MultipartFile.fromBytes(
      bytes,
      filename: md5Hex,
      contentType: DioMediaType('image', 'jpeg'),
    );
    SmartDialog.showLoading(msg: '正在上传头像');
    try {
      final response = await NetworkRepo.postChangeAvatar(file: file);
      final body = readApiObject(response);
      final newAvatar = '${body['data']}';
      if (mounted && newAvatar.isNotEmpty && newAvatar != 'null') {
        setState(() => _profile?.userAvatar = newAvatar);
      }
      SmartDialog.dismiss();
      if (mounted) SmartDialog.showToast('头像已更新');
    } catch (error) {
      SmartDialog.dismiss();
      SmartDialog.showToast(ApiFailure.fromError(error).message);
    }
  }

  Future<void> _pickCover() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      SmartDialog.showToast('读取图片失败');
      return;
    }
    final model = OssUploadModel(
      name: '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}.jpg',
      resolution: '0x0',
      md5: md5.convert(bytes).toString(),
    );
    final data = await OssUtil.onPostOSSUploadPrepare('avatar', 'cover', [model]);
    if (data == null) return;
    final client = AliyunOssClient(
      accessKeyId: data.uploadPrepareInfo!.accessKeyId!,
      accessKeySecret: data.uploadPrepareInfo!.accessKeySecret!,
      securityToken: data.uploadPrepareInfo!.securityToken!,
    );
    final config = AliyunOssConfig(
      endpoint: data.uploadPrepareInfo!.endPoint!,
      bucket: data.uploadPrepareInfo!.bucket!,
      directory: 'cover',
    );
    SmartDialog.showLoading(msg: '正在上传背景图');
    final result = await client.upload(
      id: 'cover',
      config: config,
      ossFileName:
          data.fileInfo!.first.uploadFileName!.replaceFirst('cover', ''),
      buffer: bytes,
    );
    SmartDialog.dismiss();
    if (result.state == AliyunOssResultState.fail) {
      SmartDialog.showToast('背景图上传失败，请稍后重试');
      return;
    }
    final url =
        '${data.uploadPrepareInfo!.uploadImagePrefix}/${data.fileInfo!.first.uploadFileName}';
    final ok = await _run(() => NetworkRepo.postChangeAvatarCover(url: url));
    if (ok && mounted) {
      setState(() => _profile?.cover = url);
      SmartDialog.showToast('背景图已更新');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: AppSpacing.horizontalInsets,
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _load,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: AppSpacing.pageInsets,
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(height: AppSpacing.gap),
                    _buildCoverSection(),
                    const SizedBox(height: AppSpacing.gap),
                    _buildBioSection(),
                    const SizedBox(height: AppSpacing.gap),
                    _buildGenderSection(),
                    const SizedBox(height: AppSpacing.gap),
                    _buildBirthdaySection(),
                    const SizedBox(height: AppSpacing.gap),
                    _buildRegionSection(),
                    const SizedBox(height: AppSpacing.gap),
                  ],
                ),
    );
  }

  Widget _section({required Widget child}) {
    return Material(
      color: Theme.of(context).colorScheme.onInverseSurface,
      borderRadius: const BorderRadius.all(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: child,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildAvatarSection() {
    final avatar = _profile?.userAvatar;
    return _section(
      child: Row(
        children: [
          clipNetworkImage(
            avatar ?? '',
            isAvatar: true,
            width: 56,
            height: 56,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_profile?.userInfo?.username ?? _profile?.username ?? ''),
                Text(
                  'uid: ${_profile?.uid}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _pickAvatar,
            child: const Text('更换头像'),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection() {
    final cover = _profile?.cover;
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('主页背景图'),
          SizedBox(
            width: double.infinity,
            height: 100,
            child: cover.isNullOrEmpty
                ? Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(
                      '未设置',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                : clipNetworkImage(
                    cover!,
                    width: double.infinity,
                    height: 100,
                    clipBorderRadius: const BorderRadius.all(AppRadius.small),
                  ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _pickCover,
              child: const Text('更换背景图'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('个性签名'),
          TextField(
            controller: _bioController,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: '介绍一下自己',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () => _saveField('bio', _bioController.text.trim()),
              child: const Text('保存签名'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSection() {
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('性别'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: -1, label: Text('保密')),
                ButtonSegment(value: 1, label: Text('男')),
                ButtonSegment(value: 0, label: Text('女')),
              ],
              selected: {_gender == 0 ? 0 : (_gender == 1 ? 1 : -1)},
              onSelectionChanged: (selection) {
                final value = selection.first;
                setState(() => _gender = value);
                _saveField('gender', value.toString());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdaySection() {
    final now = DateTime.now();
    final years =
        List<int>.generate(now.year - 1949, (index) => now.year - index);
    final months = List<int>.generate(12, (index) => index + 1);
    final days = List<int>.generate(31, (index) => index + 1);
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('生日'),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _yearDropdown(years),
              ),
              const SizedBox(width: 8),
              Expanded(child: _monthDropdown(months)),
              const SizedBox(width: 8),
              Expanded(child: _dayDropdown(days)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _resetField('birth'),
                child: const Text('设为保密'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _saveField(
                    '', '{"birthyear":$_year,"birthmonth":$_month,"birthday":$_day}'),
                child: const Text('保存生日'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _yearDropdown(List<int> years) {
    return DropdownButtonFormField<int>(
      initialValue: years.contains(_year) ? _year : years.first,
      isDense: true,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      items: [
        for (final item in years)
          DropdownMenuItem<int>(value: item, child: Text('$item 年')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _year = value);
      },
    );
  }

  Widget _monthDropdown(List<int> months) {
    return DropdownButtonFormField<int>(
      initialValue: months.contains(_month) ? _month : months.first,
      isDense: true,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      items: [
        for (final item in months)
          DropdownMenuItem<int>(value: item, child: Text('$item 月')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _month = value);
      },
    );
  }

  Widget _dayDropdown(List<int> days) {
    return DropdownButtonFormField<int>(
      initialValue: days.contains(_day) ? _day : days.first,
      isDense: true,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      items: [
        for (final item in days)
          DropdownMenuItem<int>(value: item, child: Text('$item 日')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _day = value);
      },
    );
  }

  Widget _buildRegionSection() {
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('地区'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _provinceController,
                  decoration: const InputDecoration(
                    labelText: '省份',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: '城市',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _resetField('location'),
                child: const Text('设为保密'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  final province = _provinceController.text.trim();
                  final city = _cityController.text.trim();
                  if (province.isEmpty && city.isEmpty) {
                    SmartDialog.showToast('请填写省份或城市');
                    return;
                  }
                  _saveField('', '{"province":"$province","city":"$city"}');
                },
                child: const Text('保存地区'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
