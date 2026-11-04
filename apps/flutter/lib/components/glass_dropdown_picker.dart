import 'package:flutter/material.dart';

import 'liquid_popup_menu.dart';

/// Settings-domain dropdown picker in the Yuxiximyxx `GlassDropdownPicker`
/// shape, adapted to the fork's own glass panel: the trigger row is just
/// the current value + a drop-down arrow (so it fits a `ListTile`
/// trailing slot), and the menu opens through [showLiquidMenu] instead
/// of a native white `DropdownButton` menu. Entries are 48dp high with
/// 16dp horizontal padding and a check on the selected item, matching
/// the reference picker's item geometry. Value semantics, labels and
/// storage keys are the caller's business and are untouched here.
class GlassDropdownPicker<T> extends StatelessWidget {
  const GlassDropdownPicker({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    this.onChanged,
    this.isExpanded = false,
  });

  final T value;
  final List<T> items;
  final String Function(T value) labelOf;

  /// Null disables the picker (greyed out, no tap), same rule as a
  /// `DropdownButton` with a null `onChanged`.
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final selected = await showLiquidMenu<T>(
      context: context,
      anchorRect: anchor,
      tooltip: labelOf(value),
      items: [
        for (final item in items)
          CheckedPopupMenuItem<T>(
            value: item,
            checked: item == value,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(labelOf(item),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
    if (selected != null) onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final theme = Theme.of(context);
    final color = enabled ? theme.colorScheme.onSurface : theme.disabledColor;
    return Builder(
      builder: (context) => InkWell(
        onTap: enabled ? () => _openMenu(context) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (isExpanded)
                Expanded(
                  child: Text(labelOf(value),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                )
              else
                Text(labelOf(value),
                    style:
                        theme.textTheme.bodyMedium?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              Icon(Icons.arrow_drop_down, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
