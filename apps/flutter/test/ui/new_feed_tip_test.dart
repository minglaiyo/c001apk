import 'package:c001apk_flutter/components/new_feed_tip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new feed tip shows count, dropdown icon and dynamic colour',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: NewFeedTip(
            count: 11,
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('更新了 11 条动态'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

    // The capsule follows the theme (dynamic colour), not a fixed colour.
    final material =
        tester.widget<Material>(find.byType(Material).first);
    expect(material.color,
        Theme.of(tester.element(find.text('更新了 11 条动态')))
            .colorScheme
            .primaryContainer);

    await tester.tap(find.text('更新了 11 条动态'));
    expect(tapped, isTrue);
  });

  testWidgets('new feed tip fades with the given opacity', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: NewFeedTip(
            count: 3,
            opacity: 0.25,
            onTap: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.25);
  });
}
