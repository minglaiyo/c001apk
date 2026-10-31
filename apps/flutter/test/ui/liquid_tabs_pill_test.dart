import 'package:c001apk_flutter/components/basic_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('liquid tabs pill slides with fractional position',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LiquidNavigationBar.tabs(
          selectedIndex: 2,
          selectedPosition: 1.5,
          labels: const ['应用', '动态', '热门'],
          onDestinationSelected: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The sliding pill is the only DecoratedBox painted with
    // primaryContainer; the per-cell pill is disabled when a fractional
    // position is given.
    final pill = find.byWidgetPredicate((widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color ==
            Theme.of(tester.element(find.text('动态')))
                .colorScheme
                .primaryContainer);
    expect(pill, findsOneWidget);

    // Default 800dp test viewport: each of the 3 cells is (800 - 8) / 3
    // wide, and the pill spans its cell +/- 2dp, so at position 1.5 it
    // sits halfway between the second and third cells.
    final rect = tester.getRect(pill);
    expect(rect.left, closeTo(402.0, 1.0));
    expect(rect.width, closeTo(260.0, 1.0));
  });
}
