import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../logic/network/api_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../../logic/reply/reply_publisher.dart';
import '../../../logic/model/oss_upload/oss_upload_model.dart';
import '../../../logic/network/network_repo.dart';
import '../../../pages/feed/reply/emoji_panel.dart';
import '../../../pages/feed/reply/toolbar_icon_button.dart';
import '../../../utils/extensions.dart';
import 'package:c001apk_flutter/constants/app_sizes.dart';
import 'package:c001apk_flutter/constants/app_motion.dart';

/// From Pilipala

enum ReplyType { feed, reply }

class ReplyDialog extends StatefulWidget {
  const ReplyDialog({
    super.key,
    this.type,
    this.id,
    this.username,
    this.targetType,
    this.targetId,
    this.title,
  });

  final ReplyType? type;
  final dynamic id;
  final String? username;
  final String? targetType;
  final dynamic targetId;
  final String? title;

  @override
  State<ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<ReplyDialog> with WidgetsBindingObserver {
  late final TextEditingController _replyContentController =
      TextEditingController(
          text: widget.targetType == 'tag' ? '#${widget.title}# ' : null);
  final FocusNode _replyContentFocusNode = FocusNode();
  late double _emoteHeight = 0.0;
  double _keyboardHeight = 0.0; // 键盘高度
  final _debouncer = Debouncer(milliseconds: 200); // 设置延迟时间

  // final _keyBoardKey = GlobalKey<ToolbarIconButtonState>();
  // final _emojiKey = GlobalKey<ToolbarIconButtonState>();
  final _publishStream = StreamController<bool>();
  bool _enablePublish = false;
  bool _publishing = false;
  final _checkBoxStream = StreamController<bool>();
  bool _checkBoxValue = false;
  late final _publisher = ReplyPublisher(
    isMounted: () => mounted,
    context: () => context,
  );

  late final _imagePicker = ImagePicker();
  late final _pathStream = StreamController<List<String>>();
  late final _pathList = <String>[];
  late final _modelList = <OssUploadModel>[];
  String? _pic;

  late final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 监听输入框聚焦
    // replyContentFocusNode.addListener(_onFocus);
    // 界面观察者 必须
    WidgetsBinding.instance.addObserver(this);
    // 自动聚焦
    _autoFocus();
    // 监听聚焦状态
    _focuslistener();
  }

  _autoFocus() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _replyContentFocusNode.requestFocus();
    }
  }

  _focuslistener() {
    _replyContentFocusNode.addListener(() {
      if (_replyContentFocusNode.hasFocus) {
        // _keyBoardKey.currentState?.updateSelected(true);
        // _emojiKey.currentState?.updateSelected(false);
      }
    });
  }

  Future _onPublish() async {
    if (_publishing) return;
    _publishing = true;
    try {
      if (_pathList.isNotEmpty) {
        final pic = await _publisher.uploadFeedImages(
          filePaths: _pathList,
          modelList: _modelList,
        );
        if (pic == null) return;
        _pic = pic;
      }
      await _publisher.publish(
        widget.id == null
            ? () => NetworkRepo.postCreateFeed(
                  FormData.fromMap(
                    {
                      'type': 'feed',
                      if (widget.targetType != null)
                        'targetType': widget.targetType,
                      if (widget.targetType == 'apk') 'type': 'comment',
                      if (widget.targetId != null) 'targetId': widget.targetId,
                      'message': _replyContentController.text,
                      'status': _checkBoxValue ? -1 : 1,
                      'pic': _pic,
                    },
                  ),
                )
            : () => NetworkRepo.postReply(
                  FormData.fromMap({
                    'message': _replyContentController.text,
                    'replyAndForward': _checkBoxValue ? 1 : 0,
                    'pic': _pic,
                  }),
                  widget.id,
                  widget.type!.name,
                ),
        successMessage: widget.id == null ? '发布成功' : null,
        withResult: widget.id != null,
      );
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(ApiFailure.fromError(e).message);
    } finally {
      _publishing = false;
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  void _onChooseEmote(String emoji) {
    final int cursorPosition = _replyContentController.selection.baseOffset;
    final String currentText = _replyContentController.text;
    final String newText = currentText.substring(0, cursorPosition) +
        emoji +
        currentText.substring(cursorPosition);
    _replyContentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition + emoji.length),
    );
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (mounted && context.mounted) {
            // 键盘高度
            final viewInsets = EdgeInsets.fromViewPadding(
                View.of(context).viewInsets, View.of(context).devicePixelRatio);
            _debouncer.run(
              () {
                if (mounted && context.mounted) {
                  if (_keyboardHeight == 0 && _emoteHeight == 0) {
                    setState(() {
                      _emoteHeight = _keyboardHeight = max(
                        200,
                        _keyboardHeight == 0.0
                            ? viewInsets.bottom
                            : _keyboardHeight,
                      );
                    });
                  }
                }
              },
            );
          }
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _publishStream.close();
    _checkBoxStream.close();
    _pathStream.close();
    _replyContentController.dispose();
    _publisher.dispose();
    _replyContentFocusNode.removeListener(() {});
    _replyContentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // double keyboardHeight = EdgeInsets.fromViewPadding(
    //         View.of(context).viewInsets, View.of(context).devicePixelRatio)
    //     .bottom;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: AppRadius.card,
          topRight: AppRadius.card,
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 200,
              minHeight: 120,
            ),
            child: Container(
              padding: const EdgeInsets.only(
                  top: 12, right: 15, left: 15, bottom: 10),
              child: SingleChildScrollView(
                child: Form(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: TextField(
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 500,
                    autofocus: false,
                    focusNode: _replyContentFocusNode,
                    controller: _replyContentController,
                    onChanged: (value) {
                      bool isNotEmpty = value.replaceAll('\n', '').isNotEmpty;
                      if (isNotEmpty && !_enablePublish) {
                        _enablePublish = true;
                        _publishStream.add(true);
                      } else if (!isNotEmpty && _enablePublish) {
                        _enablePublish = false;
                        _publishStream.add(false);
                      }
                    },
                    decoration: InputDecoration(
                        hintText: widget.username != null
                            ? '回复: ${widget.username}'
                            : '发布${widget.title != null ? '于: ${widget.title}' : '动态'}',
                        border: InputBorder.none,
                        hintStyle: const TextStyle(fontSize: 14)),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          Container(
            height: 52,
            padding: const EdgeInsets.only(left: 12, right: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ToolbarIconButton(
                  // key: _keyBoardKey,
                  onPressed: () {
                    // _keyBoardKey.currentState?.updateSelected(true);
                    // _emojiKey.currentState?.updateSelected(false);
                    _replyContentFocusNode.requestFocus();
                  },
                  icon: const Icon(Icons.keyboard, size: 22),
                  selected: true,
                ),
                const SizedBox(width: 10),
                ToolbarIconButton(
                  // key: _emojiKey,
                  onPressed: () {
                    // _keyBoardKey.currentState?.updateSelected(false);
                    // _emojiKey.currentState?.updateSelected(true);
                    FocusScope.of(context).unfocus();
                  },
                  icon: const Icon(Icons.emoji_emotions, size: 22),
                  selected: false,
                ),
                const SizedBox(width: 10),
                ToolbarIconButton(
                  selected: false,
                  icon: const Icon(Icons.image, size: 22),
                  onPressed: () async {
                    List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
                      limit: 9,
                      imageQuality: 100,
                    );
                    if (pickedFiles.isNotEmpty) {
                      try {
                        for (int i = 0; i < pickedFiles.length; i++) {
                          if (_pathList.length == 9) {
                            SmartDialog.dismiss();
                            SmartDialog.showToast('最多选择9张图片');
                            if (i != 0) {
                              _pathStream.add(_pathList);
                            }
                            break;
                          } else {
                            SmartDialog.showLoading(
                                msg: '正在加载图片: $i/${pickedFiles.length}');
                            Uint8List imageBytes =
                                await pickedFiles[i].readAsBytes();
                            ui.Image image =
                                await decodeImageFromList(imageBytes);
                            int width = image.width;
                            int height = image.height;
                            Digest md5Hash = md5.convert(imageBytes);
                            String mimeType =
                                lookupMimeType(pickedFiles[i].path) ??
                                    'image/png';
                            String name =
                                '${const Uuid().v1().replaceAll('-', '')}.${mimeType.replaceFirst('image/', '')}';
                            OssUploadModel uploadModel = OssUploadModel(
                              name: name,
                              resolution: '${width}x$height',
                              md5: md5Hash.toString(),
                            );
                            _pathList.add(pickedFiles[i].path);
                            _modelList.add(uploadModel);
                            if (i == pickedFiles.length - 1) {
                              SmartDialog.dismiss();
                              _pathStream.add(_pathList);
                            }
                          }
                        }
                      } catch (e) {
                        SmartDialog.dismiss();
                        debugPrint(e.toString());
                      }
                    }
                  },
                ),
                const Spacer(),
                StreamBuilder(
                  initialData: false,
                  stream: _checkBoxStream.stream,
                  builder: (_, snapshot) => TextButton(
                    onPressed: () {
                      _checkBoxValue = !_checkBoxValue;
                      _checkBoxStream.add(_checkBoxValue);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          side: BorderSide(
                              width: 2,
                              color: Theme.of(context).colorScheme.outline),
                          fillColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Theme.of(context).colorScheme.primary;
                            }
                            return null;
                          }),
                          value: _checkBoxValue,
                          onChanged: null,
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                        ),
                        Text(
                          widget.type == null ? '仅自己可见' : '回复并转发',
                          style: TextStyle(
                            height: 1,
                            color: _checkBoxValue
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                          strutStyle: const StrutStyle(height: 1, leading: 0),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                StreamBuilder(
                  initialData: false,
                  stream: _publishStream.stream,
                  builder: (_, snapshot) => FilledButton.tonal(
                    onPressed: snapshot.data == true ? _onPublish : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                    ),
                    child: const Text('发布'),
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder(
              stream: _pathStream.stream,
              builder: (context, snapshot) {
                if (snapshot.data.isSafeNotEmpty) {
                  return Container(
                    height: 75,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: false,
                      interactive: false,
                      thickness: 0,
                      child: ListView.separated(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        itemCount: _pathList.length,
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () {
                            _pathList.removeAt(index);
                            _modelList.removeAt(index);
                            _pathStream.add(_pathList);
                          },
                          child: Image(
                            height: 75,
                            fit: BoxFit.fitHeight,
                            filterQuality: FilterQuality.low,
                            image: FileImage(File(_pathList[index])),
                          ),
                        ),
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 10),
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }),
          AnimatedSize(
            curve: AppCurves.scrollHide,
            duration: AppDurations.scrollHide,
            child: Container(
              width: double.infinity,
              // height: _keyBoardKey.currentState?.selected == true
              //     ? (keyboardHeight > _keyboardHeight
              //         ? keyboardHeight
              //         : _keyboardHeight)
              // : _emoteHeight,
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom),
              child: EmotePanel(
                index: 1,
                onClick: (emoji) {
                  _onChooseEmote(emoji);
                  if (!_enablePublish) {
                    _enablePublish = true;
                    _publishStream.add(true);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef DebounceCallback = void Function();

class Debouncer {
  DebounceCallback? callback;
  final int? milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds});

  run(DebounceCallback callback) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds!), () {
      callback();
    });
  }
}
