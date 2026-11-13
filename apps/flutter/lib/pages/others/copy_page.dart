import '../../utils/html_text_util.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/extensions.dart';

extension StringExtensions on String {
  String get getAllLinkAndText {
    if (isEmpty) return '';
    final regExp =
        RegExp(r'<a class="feed-link-url"\s+href="([^<>\"]*)"[^<]*[^>]*>');
    return replaceAllMapped(regExp, (match) => ' ${match.group(1)} ');
  }
}

class CopyPage extends StatelessWidget {
  const CopyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String text = Get.parameters['text'].orEmpty;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Stack(
          children: [
            
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SelectableText(
                scrollPhysics: const BouncingScrollPhysics(),
                parseHtmlString(
                    '\n$text\n'.getAllLinkAndText.replaceAll("\n", "<br/>")),
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
