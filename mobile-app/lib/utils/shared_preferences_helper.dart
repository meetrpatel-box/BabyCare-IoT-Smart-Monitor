import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  SharedPrefsHelper._();

  static const String _cryHistoryKey = 'cry_history';
  static const String _maxCryHistoryEntriesKey = '_max_cry_history_entries';
  static const int _defaultMaxCryHistoryEntries = 50;

  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final existingValue = _prefs!.getInt(_maxCryHistoryEntriesKey);
    if (existingValue == null) {
      await _prefs!.setInt(
        _maxCryHistoryEntriesKey,
        _defaultMaxCryHistoryEntries,
      );
    }
  }

  static SharedPreferences get _instance {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
        'SharedPrefsHelper.initialize() must be called before use.',
      );
    }
    return prefs;
  }

  static int get _maxCryHistoryEntries =>
      _instance.getInt(_maxCryHistoryEntriesKey) ??
      _defaultMaxCryHistoryEntries;

  static List<String> getCryHistory() {
    return List<String>.from(
      _instance.getStringList(_cryHistoryKey) ?? const <String>[],
    );
  }

  static Future<void> addCryHistoryEntry(String entryJson) async {
    final history = getCryHistory();
    history.insert(0, entryJson);
    if (history.length > _maxCryHistoryEntries) {
      history.removeRange(_maxCryHistoryEntries, history.length);
    }
    await _instance.setStringList(_cryHistoryKey, history);
  }

  static Future<void> clearCryHistory() async {
    await _instance.remove(_cryHistoryKey);
  }
}
