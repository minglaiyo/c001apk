import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../utils/storage_util.dart';
import '../../pages/settings/settings_search_index.dart';
import '../../constants/liquid_glass_level.dart';
import '../expressive_list_section.dart';
import '../glass_dropdown_picker.dart';

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
      ]),
      builder: (context, _, __) {
        final enabled = GStorage.floatingNavigation && GStorage.liquidGlass;
        // ListTile limits trailing widgets to 56dp. Stack the selector when
        // larger text needs more vertical room.
        final stackPicker = MediaQuery.textScalerOf(context).scale(16) > 24;
        // The level switch itself already existed (same storage key,
        // labels and descriptions); only its popup is glassified here.
        // The level is not a no-op on the fork's fake glass: `GlassSurface`
        // maps it to blur/tint (low = flat tint, medium sigma 10,
        // high sigma 16, complete sigma 22, plus rim/sheen strength).
        // It still does not enable refraction — that needs a glass
        // pipeline the fork deliberately does not have yet.
        final picker = GlassDropdownPicker<LiquidGlassLevel>(
          value: GStorage.liquidGlassLevel,
          items: LiquidGlassLevel.values,
          labelOf: (level) => level.label,
          onChanged: enabled
              ? (level) {
                  if (level != null) {
                    GStorage.settings.put(
                        SettingsBoxKey.liquidGlassLevel, level.storedValue);
                  }
                }
              : null,
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
              subtitle: const Text('在信息流、话题、产品、搜索结果等长列表显示回顶键，长按刷新当前页，拖动可调整位置，关闭再开启可复位位置'),
              value: GStorage.backToTopEnabled,
              onChanged: (value) {
                GStorage.settings.put(SettingsBoxKey.backToTopEnabled, value);
                // The reset action lives on this switch now: turning it
                // back on clears any dragged position, falling back to
                // the stored left/right side (right by default).
                if (value) {
                  unawaited(GStorage.clearBackToTopPos());
                }
              },
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
