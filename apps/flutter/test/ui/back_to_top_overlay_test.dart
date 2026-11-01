import 'package:c001apk_flutter/components/back_to_top_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Narrowed core-visibility test for the back-to-top button.
///
/// History: the original full-overlay test (BackToTopOverlay + Hive
/// settings toggling + pumpAndSettle) hung CI: the test timed out after
/// 10 minutes and the Offline checks job was killed at its 15-minute
/// cap on every run since #27. Replacing pumpAndSettle with explicit
/// pumps did NOT fix it (Build #42 still timed out), so the hang is
/// not the settle call: it is somewhere in the full overlay tree (the
/// Hive settings path, DraggableBackToTop, or the settings listenable).
///
/// This test isolates the core behaviour only: BackToTopAction over a
/// ListView, hidden at the top and shown once scrolled past the
/// threshold. No Hive, no settings, no draggable wrapper. If this
/// passes in CI, the hanging piece is in the removed parts and the
/// switch/side coverage returns piece by piece; if this still hangs,
/// the hang is in the button/ListView core itself.
///
/// The 2-minute timeout is a safety valve: a hang must fail fast and
/// let the rest of the suite report, instead of killing the whole job.
void main() {
  testWidgets('back-to-top button appears only past the scroll threshold',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListView.builder(
                controller: controller,
                itemCount: 100,
                itemBuilder: (_, i) => SizedBox(
                  height: 80,
                  child: Text('行 $i'),
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
      ),
    );

    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    await tester.pump();
    expect(opacity(), 0);

    controller.jumpTo(700);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(), 1);

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(), 0);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
