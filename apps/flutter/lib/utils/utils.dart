
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class Utils {
  static const platform = MethodChannel('samples.flutter.dev/channel');

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
}
