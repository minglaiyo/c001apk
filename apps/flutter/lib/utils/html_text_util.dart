
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

/// 把酷安正文的 HTML 片段折叠为纯文本（保留换行）。
String parseHtmlString(String htmlString) {
  dom.Document document = html_parser.parse(htmlString);
  return _parseNode(document.body);
}

String _parseNode(dom.Node? node) {
  if (node == null) {
    return '';
  }

  if (node is dom.Element) {
    if (node.localName == 'br') {
      return '\n';
    }
    return node.nodes.map(_parseNode).join('');
  } else if (node is dom.Text) {
    return node.text;
  }

  return '';
}
