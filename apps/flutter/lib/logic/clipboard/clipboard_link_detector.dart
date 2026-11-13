import 'package:flutter/services.dart';

import '../../utils/storage_util.dart';

/// Detects Coolapk links on the clipboard, modelled on TiebaLite's
/// `ClipBoardLinkDetector`: when the app comes to the foreground, a copied
/// Coolapk link prompts the user to open it instead of needing a paste.
///
/// Only links the app itself can open are detected (coolapk.com family
/// hosts and the `coolmarket` scheme, the same hosts
/// `Utils.onOpenLink` converts). The last prompted text is remembered so
/// the same clipboard content is never prompted twice; the whole check
/// can be switched off from settings （剪贴板链接检测）.
class ClipboardLinkDetector {
  static const _coolapkHosts = {
    'coolapk.com',
    'www.coolapk.com',
    'm.coolapk.com',
    'coolapk1s.com',
    'www.coolapk1s.com',
  };

  static bool isCoolapkLink(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null) return false;
    if (uri.scheme == 'coolmarket') return true;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        _coolapkHosts.contains(uri.host)) {
      return true;
    }
    return false;
  }

  /// Returns the first Coolapk link in [text]: the whole text when it is
  /// a link, otherwise the first URL-like token that is one.
  static String? extractCoolapkLink(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (isCoolapkLink(trimmed)) return trimmed;
    for (final match in RegExp(r'(coolmarket|https?)://[^\s]+')
        .allMatches(trimmed)) {
      final candidate = match.group(0)!;
      if (isCoolapkLink(candidate)) return candidate;
    }
    return null;
  }

  /// Returns a link to prompt for, or null when detection is off, the
  /// clipboard holds no Coolapk link, or this exact text was already
  /// prompted for.
  static Future<String?> checkClipboard() async {
    if (!GStorage.clipboardLinkDetection) return null;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final link = data?.text == null ? null : extractCoolapkLink(data!.text!);
    if (link == null) return null;
    final prompted =
        GStorage.settings.get(SettingsBoxKey.clipboardLinkPrompted,
            defaultValue: '');
    if (prompted == link) return null;
    return link;
  }

  static Future<void> markPrompted(String link) =>
      GStorage.settings.put(SettingsBoxKey.clipboardLinkPrompted, link);
}
