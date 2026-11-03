import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Placeholder article editor (A layer only).
///
/// The article publish API has not been confirmed yet, so this page is
/// UI only: the submit button is always disabled and this page never
/// sends anything to any publish endpoint. It exists so the editor shape
/// (title + long body + images) can be reviewed before the probe lands.
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

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage(limit: 9);
    if (picked.isNotEmpty && mounted) {
      setState(() => _imagePaths.addAll(picked.map((file) => file.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发文章（占位）'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '文章标题',
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
                    onDeleted: () => setState(() => _imagePaths.remove(path)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '发文章接口尚未确认，本页仅为编辑器占位，不会发送任何内容。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: null,
              child: const Text('提交（发文章接口待确认，暂不可提交）'),
            ),
          ],
        ),
      ),
    );
  }
}
