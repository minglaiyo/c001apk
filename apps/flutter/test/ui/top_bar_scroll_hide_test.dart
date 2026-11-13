import 'dart:io';

import 'package:c001apk_flutter/components/liquid_top_bar.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('top-bar-scroll-');
    Hive.init(directory.path);
    GStorage.settings = await Hive.openBox('settings');
  });
  setUp(() => GStorage.settings.clear());
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: LiquidTopBarScaffold(
        title: const Text('测试'),
        onSearch: () {},
        body: ListView.builder(
          itemCount: 30,
          itemBuilder: (_, i) => SizedBox(height: 100, child: Text('项目 $i')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('top bar hides on scroll down and returns on scroll up',
      (tester) async {
    await mount(tester);
    double barHeight() =>
        tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight!;
    expect(barHeight(), kToolbarHeight);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(barHeight(), 0);
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(barHeight(), kToolbarHeight);
  });
}
