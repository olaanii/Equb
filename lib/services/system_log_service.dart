import 'dart:convert';

enum LogLevel { debug, info, warning, error, critical }

class SystemLogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;
  final Map<String, dynamic>? context;

  SystemLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.context,
  });

  Map<String, String> toCsvRow() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'source': source,
    'message': message,
    'context': context == null ? '' : jsonEncode(context),
  };
}

class SystemLogService {
  final List<SystemLogEntry> _entries = [];

  List<SystemLogEntry> list({LogLevel? level}) {
    if (level == null) return List.unmodifiable(_entries);
    return _entries.where((e) => e.level == level).toList(growable: false);
  }

  void clear() => _entries.clear();

  void log(
    LogLevel level,
    String source,
    String message, {
    Map<String, dynamic>? context,
  }) {
    _entries.add(
      SystemLogEntry(
        timestamp: DateTime.now(),
        level: level,
        source: source,
        message: _redact(message),
        context: context == null ? null : _redactMap(context),
      ),
    );
  }

  // Simple redaction for secrets/keys/tokens
  static String _redact(String input) {
    final patterns = [
      RegExp(r'(api[-_ ]?key)\s*[:=]\s*[^\s,]+', caseSensitive: false),
      RegExp(r'(secret|token)\s*[:=]\s*[^\s,]+', caseSensitive: false),
    ];
    var out = input;
    for (final p in patterns) {
      out = out.replaceAllMapped(p, (m) => '${m.group(1)}: ***');
    }
    return out;
  }

  static Map<String, dynamic> _redactMap(Map<String, dynamic> m) {
    final redacted = <String, dynamic>{};
    for (final e in m.entries) {
      final k = e.key.toLowerCase();
      if (k.contains('key') || k.contains('secret') || k.contains('token')) {
        redacted[e.key] = '***';
      } else if (e.value is String) {
        redacted[e.key] = _redact(e.value as String);
      } else {
        redacted[e.key] = e.value;
      }
    }
    return redacted;
  }

  String exportCsv({LogLevel? level}) {
    final rows = list(level: level).map((e) => e.toCsvRow()).toList();
    if (rows.isEmpty) return 'timestamp,level,source,message,context';
    final header = rows.first.keys.toList();
    final buf = StringBuffer()..writeln(header.join(','));
    for (final r in rows) {
      buf.writeln(header.map((h) => _csvEscape(r[h] ?? '')).join(','));
    }
    return buf.toString();
  }

  static String _csvEscape(String v) {
    final needsQuotes = v.contains(',') || v.contains('"') || v.contains('\n');
    var out = v.replaceAll('"', '""');
    return needsQuotes ? '"$out"' : out;
  }
}
