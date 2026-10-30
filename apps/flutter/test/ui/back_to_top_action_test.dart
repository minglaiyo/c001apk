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
}
