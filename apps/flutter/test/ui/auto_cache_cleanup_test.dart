import 'dart:io';

import 'package:c001apk_flutter/logic/cache/auto_cache_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late AutoCacheCleanupPreferences preferences;
  final now = DateTime.utc(2026, 10, 31, 12);

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('c001apk-auto-cache-');
    Hive.init(temp.path);
    box = await Hive.openBox('autoCacheCleanup');
  });

  setUp(() async {
    await box.clear();
    preferences = AutoCacheCleanupPreferences(box);
  });

  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('off by default and never cleans', () async {
    expect(preferences.intervalDays, 0);
    expect(preferences.shouldClean(now), isFalse);
    var cleaned = false;
    expect(await preferences.runIfDue(now, () async => cleaned = true),
        isFalse);
    expect(cleaned, isFalse);
    expect(preferences.lastCleaned, isNull);
  });

  test('first cleanup runs when never cleaned before', () async {
    await preferences.setIntervalDays(7);
    expect(preferences.shouldClean(now), isTrue);
    expect(await preferences.runIfDue(now, () async => true), isTrue);
    expect(preferences.lastCleaned, now);
  });

  test('7 days: not due after 3 days, due after 8 days', () async {
    await preferences.setIntervalDays(7);
    await preferences.markCleaned(now.subtract(const Duration(days: 3)));
    expect(preferences.shouldClean(now), isFalse);
    var cleaned = false;
    expect(await preferences.runIfDue(now, () async => cleaned = true),
        isFalse);
    expect(cleaned, isFalse);

    await preferences.markCleaned(now.subtract(const Duration(days: 8)));
    expect(preferences.shouldClean(now), isTrue);
    expect(await preferences.runIfDue(now, () async => true), isTrue);
    expect(preferences.lastCleaned, now);
  });

  test('3 and 15 day intervals are honoured', () async {
    await preferences.setIntervalDays(3);
    await preferences.markCleaned(now.subtract(const Duration(days: 2)));
    expect(preferences.shouldClean(now), isFalse);
    await preferences.markCleaned(now.subtract(const Duration(days: 3)));
    expect(preferences.shouldClean(now), isTrue);

    await preferences.setIntervalDays(15);
    await preferences.markCleaned(now.subtract(const Duration(days: 14)));
    expect(preferences.shouldClean(now), isFalse);
    await preferences.markCleaned(now.subtract(const Duration(days: 15)));
    expect(preferences.shouldClean(now), isTrue);
  });

  test('invalid interval is treated as off', () async {
    await box.put(AutoCacheCleanupPreferences.daysKey, 5);
    expect(preferences.intervalDays, 0);
    expect(preferences.shouldClean(now), isFalse);
    await preferences.setIntervalDays(5);
    expect(preferences.intervalDays, 0);
  });

  test('failed cleanup does not update the timestamp', () async {
    await preferences.setIntervalDays(7);
    expect(await preferences.runIfDue(now, () async => false), isFalse);
    expect(preferences.lastCleaned, isNull);
    expect(
        await preferences.runIfDue(now, () async => throw StateError('x')),
        isFalse);
    expect(preferences.lastCleaned, isNull);
  });
}
