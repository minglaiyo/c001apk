import 'package:c001apk_flutter/components/back_to_top_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('back-to-top button appears only after scrolling down',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemCount: 100,
              itemBuilder: (_, index) => SizedBox(
                height: 100,
                child: Text('item $index'),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 96,
              child: BackToTopAction(controller: controller),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // At the top the button is faded out (it stays in the tree so the
    // fade/scale animation can run, but it is not tappable).
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0);

    controller.jumpTo(1000);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  testWidgets('back-to-top button stays faded out without a controller',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BackToTopAction(controller: null),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0);
  });

  testWidgets('button colour follows the theme primaryContainer',
      (tester) async {
    const seed = Color(0xFF009688);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: const Scaffold(
        body: BackToTopAction(controller: null),
      ),
    ));
    await tester.pumpAndSettle();
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(BackToTopAction),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, scheme.primaryContainer);
    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
    expect(icon.color, scheme.onPrimaryContainer);
  });

  testWidgets('long-press scrolls to top and calls the refresh callback',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var refreshed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemCount: 100,
              itemBuilder: (_, index) => SizedBox(
                height: 100,
                child: Text('item $index'),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 96,
              child: BackToTopAction(
                controller: controller,
                onLongPress: () => refreshed = true,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    controller.jumpTo(1000);
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    expect(refreshed, isTrue);
    expect(controller.offset, 0);
  });
}
