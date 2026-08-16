import 'dart:collection';
import 'dart:convert';

typedef LogListener = void Function();

class LogEntry {
  final DateTime time;
  final String level;
  final String source;
  final String message;

  LogEntry(this.time, this.level, this.source, this.message);

  String toLine() {
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    final t = '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.${three(time.millisecond)}';
    return '[$t][$level][$source] $message';
  }
}

class AppLog {
  AppLog._();

  static final AppLog instance = AppLog._();

  static const int _maxEntries = 3000;
  final List<LogEntry> _entries = [];
  final List<LogListener> _listeners = [];
  bool _enabled = true;

  List<LogEntry> get entries => UnmodifiableListView(_entries);

  void enable() => _enabled = true;
  void disable() => _enabled = false;

  void addListener(LogListener l) => _listeners.add(l);
  void removeListener(LogListener l) => _listeners.remove(l);

  void add(String level, String source, String message) {
    if (!_enabled) return;
    _entries.add(LogEntry(DateTime.now(), level, source, message));
    if (_entries.length > _maxEntries) _entries.removeAt(0);
    for (final l in _listeners) {
      l();
    }
  }

  void info(String source, String message) => add('I', source, message);
  void warn(String source, String message) => add('W', source, message);
  void error(String source, String message) => add('E', source, message);
  void http(String source, String message) => add('H', source, message);
  void sse(String source, String message) => add('S', source, message);
  void state(String source, String message) => add('T', source, message);

  void clear() {
    _entries.clear();
    for (final l in _listeners) {
      l();
    }
  }

  /// Renders all entries as text for copy/export.
  String export() => _entries.map((e) => e.toLine()).join('\n');
}

/// JSON with one-line formatting for logging.
String logJson(Object? o) {
  try {
    return const JsonEncoder.withIndent(null).convert(o);
  } catch (_) {
    return '$o';
  }
}