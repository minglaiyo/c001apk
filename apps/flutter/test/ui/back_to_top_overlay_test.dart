import 'dart:io';

import 'package:c001apk_flutter/components/back_to_top_action.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('back-to-top-overlay-');
    Hive.init(directory.path);
    GStorage.settings = await Hive.openBox('settings');
  });
  setUp(() => GStorage.settings.clear());
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, ScrollController controller) =>
      tester.pumpWidget(MaterialApp(
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
              BackToTopOverlay(controller: controller),
            ],
          ),
        ),
      ));

  // Do NOT use pumpAndSettle here: this subtree never settles under the
  // test binding (its 10-minute pumpAndSettle timeout is what killed the
  // CI Offline checks job), so advance explicitly instead. One frame
  // flushes the settings-listener rebuild, and 300ms covers the button's
  // 200ms fade/scale animations.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('overlay follows the back-to-top switch and side setting',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    // Default: enabled, right side.
    await mount(tester, controller);
    await settle(tester);
    var positioned = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(positioned.right, 16);
    expect(positioned.left, isNull);

    // Switched off: no button at all.
    await GStorage.settings.put(SettingsBoxKey.backToTopEnabled, false);
    await settle(tester);
    expect(find.byType(BackToTopAction), findsNothing);

    // Switched on, left side.
    await GStorage.settings.put(SettingsBoxKey.backToTopEnabled, true);
    await GStorage.settings.put(SettingsBoxKey.backToTopSide, 1);
    await settle(tester);
    positioned = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(positioned.left, 16);
    expect(positioned.right, isNull);
  });
}
