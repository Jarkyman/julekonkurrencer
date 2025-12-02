import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which calendar entries are marked as "done today".
class DoneTodayService {
  static const _prefix = 'done_today_';

  Future<void> setDone(String entryId, DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(entryId);
    await prefs.setString(key, _dateKey(day));
  }

  Future<bool> isDone(String entryId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(entryId);
    final value = prefs.getString(key);
    if (value == null) return false;
    return value == _dateKey(DateTime.now());
  }

  Future<void> clearAllNotToday() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(DateTime.now());
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      final value = prefs.getString(key);
      if (value != todayKey) {
        await prefs.remove(key);
      }
    }
  }

  String _keyFor(String id) => '$_prefix$id';

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
