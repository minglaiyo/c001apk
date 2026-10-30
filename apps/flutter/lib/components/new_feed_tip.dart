import 'package:flutter/material.dart';

/// A floating capsule tip shown at the top of the home feed after a
/// refresh, modelled on TiebaLite's `RefreshTip` in
/// `ui/page/main/explore/personalized/PersonalizedPage.kt`.
///
/// TiebaLite's version is a `CircleShape` surface in
/// `colorScheme.primary` with the text "更新了 %d 条动态", shown at the
/// top centre of the list while `refreshCount > 0`. This port keeps its
/// shape (a stadium capsule), its padding (16 horizontal, 8 vertical),
/// its elevation (4) and its text, and adapts it to this app:
///
/// * Colour follows the app theme instead of a fixed colour: it uses
///   `colorScheme.primaryContainer` / `onPrimaryContainer`, which in
///   this app comes from `DynamicColorBuilder` in `main.dart` (system
///   dynamic colour when Material You is enabled, otherwise the
///   configured seed colour). That is also why the capsule reads light
///   with dark text, matching the screenshot, rather than a saturated
///   primary background with white text.
/// * A dropdown chevron sits on the right of the text, as in the
///   screenshot; the whole capsule is tappable.
/// * The caller owns visibility and fading: [opacity] is driven by the
///   caller (it fades as the user scrolls down), and [onTap] refreshes
///   the feed and hides the tip. The tip itself only renders.
class NewFeedTip extends StatelessWidget {
  const NewFeedTip({
    super.key,
    required this.count,
    required this.onTap,
    this.opacity = 1.0,
  });

  /// Number of new items, shown as "更新了 $count 条动态".
  final int count;

  /// Called when the capsule is tapped.
  final VoidCallback onTap;

  /// Fade amount, 1 fully visible to 0 fully faded out. The caller
  /// lowers this as the user scrolls down and hides the tip at 0.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: Material(
        elevation: 4,
        shape: const StadiumBorder(),
        color: colorScheme.primaryContainer,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '更新了 $count 条动态',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
