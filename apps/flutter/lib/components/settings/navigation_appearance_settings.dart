import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../utils/storage_util.dart';
import '../../pages/settings/settings_search_index.dart';
import '../../constants/liquid_glass_level.dart';
import '../expressive_list_section.dart';
import 'drop_down_menu_item.dart';

/// Separate floating/glass preferences, like KernelSU's theme settings.
class NavigationAppearanceSettings extends StatelessWidget {
  const NavigationAppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: GStorage.settings.listenable(keys: [
        SettingsBoxKey.floatingNavigation,
        SettingsBoxKey.liquidGlass,
        SettingsBoxKey.liquidGlassLevel,
        SettingsBoxKey.backToTopEnabled,
        SettingsBoxKey.backToTopSide,
      ]),
      builder: (context, _, __) {
        final enabled = GStorage.floatingNavigation && GStorage.liquidGlass;
        // ListTile limits trailing widgets to 56dp. Stack the selector when
        // larger text needs more vertical room.
        final stackPicker = MediaQuery.textScalerOf(context).scale(16) > 24;
        final picker = DropdownButtonHideUnderline(
          child: DropdownButton<LiquidGlassLevel>(
            value: GStorage.liquidGlassLevel,
            itemHeight: null,
            items: [
              for (final level in LiquidGlassLevel.values)
                DropdownMenuItem(value: level, child: Text(level.label)),
            ],
            onChanged: enabled
                ? (level) {
                    if (level != null) {
                      GStorage.settings.put(
                          SettingsBoxKey.liquidGlassLevel, level.storedValue);
                    }
                  }
                : null,
          ),
        );
        return ExpressiveListSection(children: [
          SettingsItemLocator(
            itemId: 'floatingNav',
            child: SwitchListTile(
              secondary: const Icon(Icons.call_to_action_outlined),
              title: const Text('悬浮控件'),
              subtitle: const Text('开启后，应用内的一些控件变为悬浮状态'),
              value: GStorage.floatingNavigation,
              onChanged: (value) => GStorage.settings
                  .put(SettingsBoxKey.floatingNavigation, value),
            ),
          ),
          SettingsItemLocator(
            itemId: 'liquidGlass',
            child: SwitchListTile(
              secondary: const Icon(Icons.water_drop_outlined),
              title: const Text('液态玻璃'),
              subtitle: const Text('为悬浮导航、搜索、发布和关注菜单启用玻璃效果'),
              value: GStorage.liquidGlass,
              onChanged: GStorage.floatingNavigation
                  ? (value) =>
                      GStorage.settings.put(SettingsBoxKey.liquidGlass, value)
                  : null,
            ),
          ),
          SettingsItemLocator(
            itemId: 'backToTop',
            child: SwitchListTile(
              secondary: const Icon(Icons.vertical_align_top),
              title: const Text('回顶键'),
              subtitle: const Text('在信息流、话题、产品、搜索结果等长列表显示回顶键，长按刷新当前页'),
              value: GStorage.backToTopEnabled,
              onChanged: (value) => GStorage.settings
                  .put(SettingsBoxKey.backToTopEnabled, value),
            ),
          ),
          SettingsItemLocator(
            itemId: 'backToTopSide',
            child: DropDownMenuItem(
              icon: Icons.swap_horiz,
              title: '回顶键位置',
              subtitle: '回顶键在屏幕左侧还是右侧',
              boxKey: SettingsBoxKey.backToTopSide,
              enabled: GStorage.backToTopEnabled,
              items: const [
                DropdownMenuItem<int>(value: 0, child: Text('靠右')),
                DropdownMenuItem<int>(value: 1, child: Text('靠左')),
              ],
            ),
          ),
          SettingsItemLocator(
            itemId: 'liquidGlassLevel',
            child: Semantics(
              container: true,
              child: ListTile(
                enabled: enabled,
                leading: const Icon(Icons.tune),
                title: const Text('液态玻璃档位'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(GStorage.liquidGlassLevel.description),
                  if (stackPicker) picker,
                ],
              ),
              trailing: stackPicker ? null : picker,
              ),
            ),
          ),
        ]);
      },
    );
  }
}
