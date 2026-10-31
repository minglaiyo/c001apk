import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'settings_page.dart' show SettingsDetailPage;
import 'settings_search_index.dart';

/// Search across settings, modelled on TiebaLite's settings search:
/// typing filters the index, tapping a result opens its section and
/// scrolls to the item (or opens its route for top-level entries).
class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({super.key});

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState extends State<SettingsSearchPage> {
  final _controller = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchSettings(_query);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索设置，例如：回顶键、缓存、深色',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: results.isEmpty
          ? const Center(child: Text('没有找到相关设置'))
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final entry = results[index];
                return ListTile(
                  title: Text(entry.title),
                  subtitle: Text(entry.section.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (entry.route != null) {
                      Get.toNamed(entry.route!);
                    } else {
                      Get.to(() => SettingsDetailPage(
                            section: entry.section,
                            initialItemId: entry.itemId,
                          ));
                    }
                  },
                );
              },
            ),
    );
  }
}
