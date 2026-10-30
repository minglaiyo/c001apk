import 'package:hive/hive.dart';

/// Automatic image-cache cleanup, stored in the settings box.
///
/// Interval is in days: 0 means off, otherwise one of 3, 7 or 15. Any other
/// stored value is treated as off, so a corrupted or legacy value can never
/// trigger an unexpected cleanup. The cleanup itself only removes the
/// network image cache (see `CacheManage.clearCacheAll`); it never touches
/// accounts, settings, local follows or other stored data.
///
/// The check runs on app launch only, like the automatic update check:
/// if the interval has elapsed since the last cleanup (or there has never
/// been one), the cache is cleared and the timestamp is updated. A failed
/// cleanup does not update the timestamp, so it is retried on the next
/// launch instead of silently skipping a whole interval.
class AutoCacheCleanupPreferences {
  AutoCacheCleanupPreferences(this.box);

  final Box<dynamic> box;

  static const daysKey = 'autoCacheCleanupDays';
  static const _lastKey = 'autoCacheCleanupLastMillis';

  static const allowedDays = <int>[0, 3, 7, 15];

  int get intervalDays {
    final value = box.get(daysKey, defaultValue: 0);
    if (value is int && allowedDays.contains(value)) return value;
    return 0;
  }

  Future<void> setIntervalDays(int days) =>
      box.put(daysKey, allowedDays.contains(days) ? days : 0);

  DateTime? get lastCleaned {
    final value = box.get(_lastKey);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  bool shouldClean(DateTime now) {
    final interval = intervalDays;
    if (interval == 0) return false;
    final last = lastCleaned;
    if (last == null) return true;
    return now.difference(last) >= Duration(days: interval);
  }

  Future<void> markCleaned(DateTime now) =>
      box.put(_lastKey, now.millisecondsSinceEpoch);

  /// Returns true only when a cleanup actually ran and succeeded.
  Future<bool> runIfDue(
    DateTime now,
    Future<bool> Function() clearCache,
  ) async {
    if (!shouldClean(now)) return false;
    bool cleared;
    try {
      cleared = await clearCache();
    } catch (_) {
      return false;
    }
    if (!cleared) return false;
    await markCleaned(now);
    return true;
  }
}
