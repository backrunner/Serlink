import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../security/local_file_security.dart';
import 'redactor.dart';

enum DiagnosticLogLevel { info, warning, error }

abstract interface class DiagnosticLogger {
  Future<void> record(
    String event, {
    DiagnosticLogLevel level,
    Map<String, Object?> details,
  });
}

class NoopDiagnosticLogger implements DiagnosticLogger {
  const NoopDiagnosticLogger();

  @override
  Future<void> record(
    String event, {
    DiagnosticLogLevel level = DiagnosticLogLevel.info,
    Map<String, Object?> details = const {},
  }) async {}
}

class DiagnosticLogFile {
  const DiagnosticLogFile({
    required this.name,
    required this.bytes,
    required this.lineCount,
  });

  final String name;
  final List<int> bytes;
  final int lineCount;
}

typedef DiagnosticLogDirectoryProvider = Future<Directory> Function();

class OfflineDiagnosticLogger implements DiagnosticLogger {
  OfflineDiagnosticLogger({
    DiagnosticLogDirectoryProvider? directoryProvider,
    DateTime Function()? now,
    this.maxFileBytes = defaultMaxFileBytes,
    this.maxRetentionDays = defaultMaxRetentionDays,
    this.maxLineBytes = defaultMaxLineBytes,
  }) : assert(maxFileBytes > 0),
       assert(maxRetentionDays > 0),
       assert(maxLineBytes > 0),
       _directoryProvider = directoryProvider ?? defaultLogDirectory,
       _now = now ?? DateTime.now;

  static const defaultMaxFileBytes = 20 * 1024 * 1024;
  static const defaultMaxRetentionDays = 5;
  static const defaultMaxLineBytes = 8 * 1024;
  static final _logNamePattern = RegExp(
    r'^serlink-(\d{4}-\d{2}-\d{2})(?:\.(\d+))?\.log$',
  );
  static final _legacyLogNamePattern = RegExp(r'^serlink\.log(?:\.\d+)?$');

  final DiagnosticLogDirectoryProvider _directoryProvider;
  final DateTime Function() _now;
  final int maxFileBytes;
  final int maxRetentionDays;
  final int maxLineBytes;
  Future<void> _pending = Future<void>.value();

  static Future<Directory> defaultLogDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return Directory('${appDir.path}/Serlink/logs');
  }

  @override
  Future<void> record(
    String event, {
    DiagnosticLogLevel level = DiagnosticLogLevel.info,
    Map<String, Object?> details = const {},
  }) {
    final timestamp = _now().toUtc();
    final line = _formatLine(
      timestamp: timestamp,
      event: event,
      level: level,
      details: details,
    );
    final write = _pending
        .then((_) => _writeLine(line, timestamp: timestamp))
        .catchError((_) {
          // Diagnostic logging must never affect app workflows.
        });
    _pending = write;
    return write;
  }

  Future<List<DiagnosticLogFile>> readLogFiles() async {
    try {
      final directory = await _directoryProvider();
      await _pruneOldLogFiles(directory);
      final files = <DiagnosticLogFile>[];
      for (final candidate in await _logFilesOldestFirst(directory)) {
        final redacted = Redactor.redact(await candidate.file.readAsString());
        files.add(
          DiagnosticLogFile(
            name: candidate.file.uri.pathSegments.last,
            bytes: utf8.encode(redacted),
            lineCount: const LineSplitter().convert(redacted).length,
          ),
        );
      }
      return files;
    } on Object {
      return const [];
    }
  }

  String _formatLine({
    required DateTime timestamp,
    required String event,
    required DiagnosticLogLevel level,
    required Map<String, Object?> details,
  }) {
    final payload = <String, Object?>{
      'ts': timestamp.toIso8601String(),
      'level': level.name,
      'event': Redactor.redact(event),
      if (details.isNotEmpty) 'details': _redactedDetails(details),
    };
    var bytes = utf8.encode('${jsonEncode(payload)}\n');
    final lineByteLimit = maxLineBytes < maxFileBytes
        ? maxLineBytes
        : maxFileBytes;
    if (bytes.length <= lineByteLimit) {
      return utf8.decode(bytes);
    }
    final fallback = <String, Object?>{
      'ts': payload['ts'],
      'level': level.name,
      'event': Redactor.redact(event),
      'details': {'truncated': true, 'originalLineBytes': bytes.length},
    };
    bytes = utf8.encode('${jsonEncode(fallback)}\n');
    return utf8.decode(bytes);
  }

  Future<void> _writeLine(String line, {required DateTime timestamp}) async {
    final directory = await _directoryProvider();
    await LocalFileSecurity.preparePrivateDirectory(directory);
    await _pruneOldLogFiles(directory);
    final bytes = utf8.encode(line);
    final file = await _selectLogFileForWrite(
      directory,
      timestamp: timestamp,
      incomingBytes: bytes.length,
    );
    await file.writeAsBytes(bytes, mode: FileMode.append, flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    await _pruneOldLogFiles(directory);
  }

  Future<File> _selectLogFileForWrite(
    Directory directory, {
    required DateTime timestamp,
    required int incomingBytes,
  }) async {
    final dateKey = _logDateKey(timestamp);
    var segment = 0;
    while (true) {
      final file = _logFile(directory, dateKey: dateKey, segment: segment);
      if (!await file.exists()) {
        return file;
      }
      final length = await file.length();
      if (length + incomingBytes <= maxFileBytes) {
        return file;
      }
      segment += 1;
    }
  }

  Future<void> _pruneOldLogFiles(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    await _deleteLegacyLogFiles(directory);
    final files = await _discoverLogFiles(directory);
    final dates = <String>{
      for (final file in files) _logDateKey(file.date),
    }.toList()..sort();
    final keepDates = dates.length <= maxRetentionDays
        ? dates.toSet()
        : dates.skip(dates.length - maxRetentionDays).toSet();
    for (final file in files) {
      if (!keepDates.contains(_logDateKey(file.date))) {
        await file.file.delete();
      }
    }
  }

  Future<List<_ParsedLogFile>> _logFilesOldestFirst(Directory directory) async {
    final files = await _discoverLogFiles(directory);
    files.sort((left, right) {
      final dateComparison = left.date.compareTo(right.date);
      if (dateComparison != 0) {
        return dateComparison;
      }
      final segmentComparison = left.segment.compareTo(right.segment);
      if (segmentComparison != 0) {
        return segmentComparison;
      }
      return left.file.path.compareTo(right.file.path);
    });
    return files;
  }

  Future<List<_ParsedLogFile>> _discoverLogFiles(Directory directory) async {
    if (!await directory.exists()) {
      return const [];
    }
    final files = <_ParsedLogFile>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final parsed = _parseLogFile(entity);
      if (parsed != null) {
        files.add(parsed);
      }
    }
    return files;
  }

  Future<void> _deleteLegacyLogFiles(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      if (!OfflineDiagnosticLogger._legacyLogNamePattern.hasMatch(name)) {
        continue;
      }
      try {
        await entity.delete();
      } on Object {
        // Best-effort cleanup; logging should keep working if deletion fails.
      }
    }
  }

  File _logFile(
    Directory directory, {
    required String dateKey,
    required int segment,
  }) {
    final suffix = segment == 0 ? '' : '.$segment';
    return File('${directory.path}/serlink-$dateKey$suffix.log');
  }
}

class _ParsedLogFile {
  const _ParsedLogFile({
    required this.file,
    required this.date,
    required this.segment,
  });

  final File file;
  final DateTime date;
  final int segment;
}

_ParsedLogFile? _parseLogFile(File file) {
  final name = file.uri.pathSegments.last;
  final match = OfflineDiagnosticLogger._logNamePattern.firstMatch(name);
  if (match == null) {
    return null;
  }
  final date = DateTime.tryParse(match.group(1)!);
  if (date == null) {
    return null;
  }
  final segment = int.tryParse(match.group(2) ?? '0');
  if (segment == null) {
    return null;
  }
  return _ParsedLogFile(
    file: file,
    date: DateTime.utc(date.year, date.month, date.day),
    segment: segment,
  );
}

String _logDateKey(DateTime value) {
  final utc = value.toUtc();
  return [
    utc.year.toString().padLeft(4, '0'),
    utc.month.toString().padLeft(2, '0'),
    utc.day.toString().padLeft(2, '0'),
  ].join('-');
}

Map<String, Object?> _redactedDetails(Map<String, Object?> details) {
  return {
    for (final entry in details.entries)
      entry.key: _sensitiveKey(entry.key)
          ? '[redacted]'
          : _redactedValue(entry.value),
  };
}

Object? _redactedValue(Object? value) {
  return switch (value) {
    null => null,
    bool() || num() => value,
    DateTime() => value.toUtc().toIso8601String(),
    Enum() => value.name,
    String() => Redactor.redact(_truncate(value)),
    Map() => {
      for (final entry in value.entries)
        entry.key.toString(): _sensitiveKey(entry.key.toString())
            ? '[redacted]'
            : _redactedValue(entry.value),
    },
    Iterable() => [
      for (final item in value.take(20)) _redactedValue(item),
      if (value.length > 20) {'truncatedItems': value.length - 20},
    ],
    _ => Redactor.redact(_truncate(value.toString())),
  };
}

bool _sensitiveKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized.contains('password') ||
      normalized.contains('passphrase') ||
      normalized.contains('privatekey') ||
      normalized.contains('credential') ||
      normalized.contains('secret') ||
      normalized.contains('token') ||
      normalized == 'user' ||
      normalized == 'username' ||
      normalized == 'host' ||
      normalized == 'hostname' ||
      normalized == 'path' ||
      normalized == 'command';
}

String _truncate(String value, {int maxLength = 1024}) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength)}...[truncated]';
}
