import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/liquid_glass_level.dart';
import 'package:c001apk_flutter/constants/app_sizes.dart';

/// Public backend: ordinary translucent/frosted surfaces and navigation.
/// The official source assembly supplies the same API with its own renderer.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.shader,
    required this.enabled,
    required this.extent,
    required this.depth,
    required this.dispersion,
    required this.tint,
    this.refractionHeight = 0,
    this.depthEffect = false,
    this.blur = 4,
    this.fallbackTint,
    this.level = LiquidGlassLevel.medium,
    this.press = 0,
    this.borderRadius,
    this.shadow = true,
    this.glow = 1,
  });

  factory GlassSurface.navigationBase({
    required ui.FragmentShader? shader,
    required bool enabled,
    required Size extent,
    required ThemeData theme,
    required LiquidGlassLevel level,
    BorderRadius? borderRadius,
    bool shadow = true,
    double press = 0,
    double glow = 1,
  }) =>
      GlassSurface(
          shader: shader,
          enabled: enabled,
          extent: extent,
          depth: 0,
          dispersion: 0,
          tint: theme.colorScheme.surfaceContainer,
          level: level,
          borderRadius: borderRadius,
          shadow: shadow,
          press: press,
          glow: glow);

  factory GlassSurface.navigationLens({
    required ui.FragmentShader? shader,
    required bool enabled,
    required Size extent,
    required ThemeData theme,
    required LiquidGlassLevel level,
    required double progress,
    bool shadow = true,
    Color? tint,
    double glow = 1,
  }) =>
      GlassSurface(
          shader: shader,
          enabled: enabled,
          extent: extent,
          depth: 0,
          dispersion: 0,
          tint: tint ?? theme.colorScheme.primaryContainer,
          level: level,
          depthEffect: true,
          shadow: shadow,
          press: progress,
          glow: glow);

  final ui.FragmentShader? shader;
  final bool enabled, depthEffect, shadow;
  final Size extent;
  final double depth, dispersion, refractionHeight, blur, press, glow;
  final Color tint;
  final Color? fallbackTint;
  final LiquidGlassLevel level;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(extent.height / 2);
    final solid = !enabled || MediaQuery.highContrastOf(context);
    final baseTint = fallbackTint ?? tint;
    // Flat opaque surface for low level / disabled / high contrast,
    // exactly as before.
    if (solid || level == LiquidGlassLevel.low) {
      return ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: baseTint.withValues(alpha: solid ? 1 : .9),
          child: const SizedBox.expand(),
        ),
      );
    }
    // Fake glass, made less flat: blur strength grows with the level
    // (the old code used sigma 4 for every non-low level), the tint is
    // a top-light gradient instead of one flat colour, a 1px rim catches
    // light from above, and a soft top sheen sits over it all. This is
    // still blur + tint, not refraction, but the levels now actually
    // look different from each other.
    double sigma;
    double rimBase;
    if (level == LiquidGlassLevel.medium) {
      sigma = 10;
      rimBase = 0.22;
    } else if (level == LiquidGlassLevel.high) {
      sigma = 16;
      rimBase = 0.35;
    } else {
      sigma = 22;
      rimBase = 0.5;
    }
    // Scroll-linked brightness: glow is the bar's show progress
    // (1 = fully shown). As a bar hides with scrolling its glass dims
    // slightly on top of the existing fade, instead of staying flat.
    final glowFactor = 0.6 + 0.4 * glow.clamp(0.0, 1.0);
    final rim = rimBase * glowFactor;
    final sheen = Colors.white.withValues(alpha: 0.10 * glowFactor);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: rim),
              Colors.white.withValues(alpha: rim * 0.3),
              Colors.transparent,
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        baseTint.withValues(alpha: 0.72),
                        baseTint.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [sheen, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel(
      {super.key,
      required this.child,
      required this.enabled,
      required this.level,
      this.borderRadius = const BorderRadius.all(AppRadius.glass)});
  final Widget child;
  final bool enabled;
  final LiquidGlassLevel level;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: borderRadius,
      child: Stack(clipBehavior: Clip.hardEdge, alignment: Alignment.center, children: [
        Positioned.fill(
            child: IgnorePointer(
                child: LayoutBuilder(
                    builder: (context, bounds) => GlassSurface(
                        shader: null,
                        enabled: enabled,
                        extent: bounds.biggest,
                        depth: 0,
                        dispersion: 0,
                        tint: Theme.of(context).colorScheme.surfaceContainer,
                        level: level,
                        borderRadius: borderRadius)))),
        child,
      ]));
}

class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton(
      {super.key,
      required this.child,
      required this.height,
      required this.level,
      required this.onPressed,
      required this.tooltip,
      this.width,
      this.enabled = true});
  final Widget child;
  final double height;
  final double? width;
  final LiquidGlassLevel level;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        IgnorePointer(
            child: GlassSurface.navigationBase(
                shader: null,
                enabled: enabled,
                extent: Size(width ?? height, height),
                theme: Theme.of(context),
                level: level,
                shadow: false)),
        Tooltip(
            message: tooltip,
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(height / 2),
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Center(child: child))))),
      ]));
}

class LiquidNavigationBar extends StatefulWidget {
  const LiquidNavigationBar(
      {super.key,
      required this.selectedIndex,
      required this.onDestinationSelected,
      this.program,
      this.refract = true,
      this.direction = Axis.horizontal,
      this.level = LiquidGlassLevel.medium,
      this.glow = 1})
      : labels = const ['主页', '关注', '我的'],
        selectedPosition = null,
        tabs = false;
  const LiquidNavigationBar.tabs(
      {super.key,
      required this.selectedIndex,
      required this.onDestinationSelected,
      required this.labels,
      this.selectedPosition,
      this.program,
      this.refract = true,
      this.direction = Axis.horizontal,
      this.level = LiquidGlassLevel.medium,
      this.glow = 1})
      : tabs = true;
  final int selectedIndex;
  // Bar show progress (1 = fully shown), driven by the scroll-hide
  // animation. Scales the glass rim/sheen brightness with scrolling.
  final double glow;
  // Fractional selected position (e.g. a TabController animation value).
  // When set, the selected pill slides continuously instead of jumping
  // between cells when selectedIndex flips at the end of a transition.
  final double? selectedPosition;
  final ValueChanged<int> onDestinationSelected;
  final ui.FragmentProgram? program;
  final bool refract, tabs;
  final Axis direction;
  final LiquidGlassLevel level;
  final List<String> labels;

  @override
  State<LiquidNavigationBar> createState() => _BasicNavigationState();
}

class _BasicNavigationState extends State<LiquidNavigationBar> {
  int? _dragIndex;
  bool get _vertical => widget.direction == Axis.vertical;

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      bottom: !widget.tabs && !_vertical,
      minimum: widget.tabs || _vertical
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
              constraints: _vertical
                  ? const BoxConstraints(maxHeight: 176, maxWidth: 128)
                  : BoxConstraints(
                      maxWidth: widget.tabs ? double.infinity : 248),
              child: LayoutBuilder(builder: (context, bounds) {
                if (widget.labels.isEmpty || bounds.maxWidth <= 0) {
                  return const SizedBox.shrink();
                }
                final theme = Theme.of(context);
                final textHeight = MediaQuery.textScalerOf(context).scale(14);
                final height = widget.tabs
                    ? math.max(48.0, textHeight + 24)
                    : math.max(64.0, textHeight + 40);
                final length = _vertical ? bounds.maxHeight : bounds.maxWidth;
                // With a fractional position the pill follows the
                // transition; without one it stays on the selected cell,
                // exactly as before.
                final double effectivePosition =
                    (_dragIndex?.toDouble() ??
                            widget.selectedPosition ??
                            widget.selectedIndex.toDouble())
                        .clamp(0.0, (widget.labels.length - 1).toDouble());
                final selected = widget.selectedPosition == null
                    ? (_dragIndex ?? widget.selectedIndex)
                        .clamp(0, widget.labels.length - 1)
                    : effectivePosition.round()
                        .clamp(0, widget.labels.length - 1);
                void drag(Offset point) => setState(() => _dragIndex =
                    ((_vertical ? point.dy : point.dx) /
                            length *
                            widget.labels.length)
                        .floor()
                        .clamp(0, widget.labels.length - 1));
                // The Row below has 4dp horizontal padding and equal-width
                // Expanded cells, so a cell is (maxWidth - 8) / count wide
                // and the per-cell pill spans cell +/- 2dp horizontally.
                final cellWidth =
                    (bounds.maxWidth - 8) / widget.labels.length;
                return _BasicRoundHitRegion(
                    child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(_vertical ? 28 : height / 2),
                        child: GestureDetector(
                          key: ValueKey(widget.tabs
                              ? 'liquid-tabs-surface'
                              : 'liquid-drag-surface'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onHorizontalDragUpdate: _vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onHorizontalDragCancel: _vertical
                              ? null
                              : () => setState(() => _dragIndex = null),
                          onHorizontalDragEnd: _vertical
                              ? null
                              : (_) {
                                  final index = _dragIndex;
                                  setState(() => _dragIndex = null);
                                  if (index != null) {
                                    widget.onDestinationSelected(index);
                                  }
                                },
                          onVerticalDragStart: !_vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onVerticalDragUpdate: !_vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onVerticalDragCancel: !_vertical
                              ? null
                              : () => setState(() => _dragIndex = null),
                          onVerticalDragEnd: !_vertical
                              ? null
                              : (_) {
                                  final index = _dragIndex;
                                  setState(() => _dragIndex = null);
                                  if (index != null) {
                                    widget.onDestinationSelected(index);
                                  }
                                },
                          child: SizedBox(
                              height: _vertical ? length : height,
                              child: Stack(children: [
                                Positioned.fill(
                                    child: IgnorePointer(
                                        child: GlassSurface.navigationBase(
                                            shader: null,
                                            borderRadius: _vertical
                                                ? AppRadius.glassAll
                                                : null,
                                            enabled: widget.refract,
                                            extent: _vertical
                                                ? Size(bounds.maxWidth, length)
                                                : Size(bounds.maxWidth, height),
                                            theme: theme,
                                            level: widget.level,
                                            shadow: false,
                                            glow: widget.glow))),
                                // Sliding pill: same rect as the per-cell
                                // pill at integer positions, but it moves
                                // continuously with effectivePosition.
                                // (Horizontal tabs only; vertical rails
                                // jump between cells.)
                                if (widget.selectedPosition != null && !_vertical)
                                  Positioned(
                                      left: 4 +
                                          effectivePosition * cellWidth +
                                          2,
                                      width: cellWidth - 4,
                                      top: 4,
                                      bottom: 4,
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: theme.colorScheme
                                                  .primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      height / 2)))),
                                Padding(
                                  padding: _vertical
                                      ? const EdgeInsets.symmetric(vertical: 4)
                                      : const EdgeInsets.symmetric(horizontal: 4),
                                  child: Flex(
                                  direction: widget.direction,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0;
                                        i < widget.labels.length;
                                        i++)
                                      Expanded(
                                          child: Semantics(
                                              label: widget.labels[i],
                                              excludeSemantics: true,
                                              selected: selected == i,
                                              button: true,
                                              inMutuallyExclusiveGroup: true,
                                              child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    if (widget.selectedPosition ==
                                                            null &&
                                                        selected == i)
                                                      Positioned.fill(
                                                          child: Padding(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 2, vertical: 4),
                                                              child: DecoratedBox(
                                                                  decoration: BoxDecoration(
                                                                      color: theme.colorScheme.primaryContainer,
                                                                      borderRadius: BorderRadius.circular(height / 2))))),
                                                    TextButton(
                                                  onPressed: () => widget
                                                      .onDestinationSelected(i),
                                                  style: TextButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 2),
                                                      backgroundColor: Colors.transparent,
                                                      foregroundColor: selected == i
                                                          ? theme.colorScheme
                                                              .onPrimaryContainer
                                                          : theme.colorScheme
                                                              .onSurface,
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(height / 2))),
                                                  child: widget.tabs
                                                      ? Text(widget.labels[i],
                                                          maxLines: 1)
                                                      : Flex(direction: _vertical ? Axis.horizontal : Axis.vertical, mainAxisSize: MainAxisSize.min, children: [
                                                          Icon([
                                                            Icons.home_outlined,
                                                            Icons.feed_outlined,
                                                            Icons.person_outline
                                                          ][i % 3]),
                                                          if (_vertical)
                                                            const SizedBox(
                                                                width: 10),
                                                          Text(widget.labels[i],
                                                              maxLines: 1),
                                                        ])),
                                                  ])))
                                  ],
                                ),
                                ),
                              ])),
                        )));
              }))));
}

class _BasicRoundHitRegion extends SingleChildRenderObjectWidget {
  const _BasicRoundHitRegion({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _BasicRoundHitBox();
}

class _BasicRoundHitBox extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      RRect.fromRectAndRadius(
              Offset.zero & size,
              Radius.circular(size.height > size.width ? 28 : size.height / 2))
          .contains(position) &&
      super.hitTest(result, position: position);
}
