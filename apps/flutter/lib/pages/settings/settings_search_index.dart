import 'package:flutter/material.dart';

import 'settings_page.dart' show SettingsSection;

/// One searchable settings entry, modelled on TiebaLite's
/// `SettingsSearchIndex`: a title, the section that owns it, extra
/// keywords, and either the detail-page item it locates ([itemId]) or a
/// route to open directly ([route]).
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.title,
    required this.section,
    this.itemId,
    this.route,
    this.keywords = const [],
  });

  final String title;
  final SettingsSection section;
  final String? itemId;
  final String? route;
  final List<String> keywords;
}

const List<SettingsSearchEntry> settingsSearchEntries = [
  // 外观与字号
  SettingsSearchEntry(
    title: '动态取色',
    section: SettingsSection.appearance,
    itemId: 'dynamicColor',
    keywords: ['主题', '配色', 'Material You', '系统配色'],
  ),
  SettingsSearchEntry(
    title: '主题颜色',
    section: SettingsSection.appearance,
    itemId: 'themeColor',
    keywords: ['固定配色', '配色'],
  ),
  SettingsSearchEntry(
    title: '深色模式',
    section: SettingsSection.appearance,
    itemId: 'darkMode',
    keywords: ['浅色', '深色', '跟随系统', '夜间'],
  ),
  SettingsSearchEntry(
    title: '不写东西',
    section: SettingsSection.appearance,
    itemId: 'hidePublish',
    keywords: ['发布入口', '隐藏'],
  ),
  SettingsSearchEntry(
    title: '悬浮控件',
    section: SettingsSection.appearance,
    itemId: 'floatingNav',
    keywords: ['悬浮', '导航'],
  ),
  SettingsSearchEntry(
    title: '液态玻璃',
    section: SettingsSection.appearance,
    itemId: 'liquidGlass',
    keywords: ['玻璃效果', '悬浮导航', '搜索', '发布', '关注菜单'],
  ),
  SettingsSearchEntry(
    title: '回顶键',
    section: SettingsSection.appearance,
    itemId: 'backToTop',
    keywords: ['回到顶部', '长按刷新'],
  ),
  SettingsSearchEntry(
    title: '回顶键位置',
    section: SettingsSection.appearance,
    itemId: 'backToTopSide',
    keywords: ['靠左', '靠右', '左侧', '右侧'],
  ),
  SettingsSearchEntry(
    title: '液态玻璃档位',
    section: SettingsSection.appearance,
    itemId: 'liquidGlassLevel',
    keywords: ['等级', '档位'],
  ),
  SettingsSearchEntry(
    title: '分栏阅读',
    section: SettingsSection.appearance,
    itemId: 'readingMode',
    keywords: ['双栏', '横屏', '单页'],
  ),
  SettingsSearchEntry(
    title: '字体大小',
    section: SettingsSection.appearance,
    itemId: 'fontSize',
    keywords: ['字号', '文字大小'],
  ),
  // 关注与内容
  SettingsSearchEntry(
    title: '悄悄关注',
    section: SettingsSection.content,
    itemId: 'quietFollow',
    keywords: ['关注', '长按'],
  ),
  SettingsSearchEntry(
    title: '本地关注',
    section: SettingsSection.content,
    itemId: 'localFollow',
    keywords: ['游客', '关注', '名单'],
  ),
  SettingsSearchEntry(
    title: '管理关注名单',
    section: SettingsSection.content,
    itemId: 'manageLocalFollow',
    keywords: ['本地关注', '悄悄关注', '名单', '取消关注'],
  ),
  SettingsSearchEntry(
    title: '显示表情',
    section: SettingsSection.content,
    itemId: 'showEmoji',
    keywords: ['表情', '图片'],
  ),
  // 浏览与隐私
  SettingsSearchEntry(
    title: '自动加载实况图片',
    section: SettingsSection.privacy,
    itemId: 'livePhotoAutoLoad',
    keywords: ['实况', '大图', '自动播放', '图片加载'],
  ),
  SettingsSearchEntry(
    title: '屏蔽傻逼内容',
    section: SettingsSection.privacy,
    itemId: 'contentFilter',
    keywords: ['内容过滤', '规则', '例外', '屏蔽'],
  ),
  SettingsSearchEntry(
    title: '用户黑名单',
    section: SettingsSection.privacy,
    itemId: 'userBlacklist',
    keywords: ['屏蔽用户', '黑名单', '隐藏动态'],
  ),
  SettingsSearchEntry(
    title: '话题黑名单',
    section: SettingsSection.privacy,
    itemId: 'topicBlacklist',
    keywords: ['关键词', '过滤话题'],
  ),
  SettingsSearchEntry(
    title: '记录浏览历史',
    section: SettingsSection.privacy,
    itemId: 'recordHistory',
    keywords: ['历史', '浏览过的动态'],
  ),
  SettingsSearchEntry(
    title: '在浏览器中打开',
    section: SettingsSection.privacy,
    itemId: 'openInBrowser',
    keywords: ['外部链接', '系统浏览器', '网页'],
  ),
  SettingsSearchEntry(
    title: '剪贴板链接检测',
    section: SettingsSection.privacy,
    itemId: 'clipboardLink',
    keywords: ['剪贴板', '复制链接', '酷安链接', '跳转'],
  ),
  // 存储与更新
  SettingsSearchEntry(
    title: '自动检查 c001apk 更新',
    section: SettingsSection.storage,
    itemId: 'autoUpdateCheck',
    keywords: ['更新', '启动时检查', '正式版本'],
  ),
  SettingsSearchEntry(
    title: '检查更新',
    section: SettingsSection.storage,
    itemId: 'checkUpdateNow',
    keywords: ['最新正式版本', '手动检查'],
  ),
  SettingsSearchEntry(
    title: '检查已安装应用更新',
    section: SettingsSection.storage,
    itemId: 'checkInstalledAppUpdate',
    keywords: ['应用列表', '已安装应用', '更新入口'],
  ),
  SettingsSearchEntry(
    title: '自动清理缓存',
    section: SettingsSection.storage,
    itemId: 'autoCacheCleanup',
    keywords: ['缓存', '每3天', '每7天', '每15天', '图片缓存'],
  ),
  SettingsSearchEntry(
    title: '清理缓存',
    section: SettingsSection.storage,
    itemId: 'clearCache',
    keywords: ['缓存', '手动清理', '图片缓存'],
  ),
  // 协议与设备
  SettingsSearchEntry(
    title: '设备标识',
    section: SettingsSection.protocol,
    itemId: 'deviceIdentity',
    keywords: ['自动获取', '人机验证', '手动导入'],
  ),
  SettingsSearchEntry(
    title: '协议参数',
    section: SettingsSection.protocol,
    itemId: 'params',
    keywords: ['客户端版本', '设备', '请求参数'],
  ),
  // 设置首页直达项
  SettingsSearchEntry(
    title: '使用引导',
    section: SettingsSection.appearance,
    route: '/onboarding',
    keywords: ['引导', '发布偏好', '内容屏蔽', '重新选择'],
  ),
  SettingsSearchEntry(
    title: '账号管理',
    section: SettingsSection.appearance,
    route: '/accounts',
    keywords: ['账号', '切换', '添加', '移除'],
  ),
  SettingsSearchEntry(
    title: '关于',
    section: SettingsSection.appearance,
    route: '/about',
    keywords: ['版本', '信息'],
  ),
];

/// Substring match: every whitespace-separated token of the query must
/// appear in the entry title, its section title, or its keywords.
/// An empty query returns the whole index (browsable).
List<SettingsSearchEntry> searchSettings(String query) {
  final tokens = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return settingsSearchEntries;
  return settingsSearchEntries.where((entry) {
    final haystack =
        '${entry.title} ${entry.section.title} ${entry.keywords.join(' ')}'
            .toLowerCase();
    return tokens.every(haystack.contains);
  }).toList();
}

/// Marks a settings item so a search result can scroll to it. The widget
/// registers its own context while mounted; [contextFor] returns it for
/// `Scrollable.ensureVisible` in the detail page.
class SettingsItemLocator extends StatefulWidget {
  const SettingsItemLocator({
    super.key,
    required this.itemId,
    required this.child,
  });

  final String itemId;
  final Widget child;

  static final _contexts = <String, BuildContext>{};

  static BuildContext? contextFor(String itemId) => _contexts[itemId];

  @override
  State<SettingsItemLocator> createState() => _SettingsItemLocatorState();
}

class _SettingsItemLocatorState extends State<SettingsItemLocator> {
  @override
  Widget build(BuildContext context) {
    SettingsItemLocator._contexts[widget.itemId] = context;
    return widget.child;
  }

  @override
  void dispose() {
    if (SettingsItemLocator._contexts[widget.itemId] == context) {
      SettingsItemLocator._contexts.remove(widget.itemId);
    }
    super.dispose();
  }
}
