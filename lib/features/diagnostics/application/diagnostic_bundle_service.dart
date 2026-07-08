import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/logging/offline_diagnostic_logger.dart';
import '../../../core/logging/redactor.dart';
import '../../../core/runtime/runtime_mode.dart';
import '../../vault/application/vault_service.dart';

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef CrashLastEventIdReader = String Function();
typedef DiagnosticLogTailReader = Future<List<String>> Function();
typedef DiagnosticLogFileReader = Future<List<DiagnosticLogFile>> Function();

class DiagnosticBundle {
  const DiagnosticBundle({
    required this.createdAt,
    required this.manifest,
    required this.bytes,
  });

  final DateTime createdAt;
  final Map<String, Object?> manifest;
  final List<int> bytes;
}

class RuntimeDebugLogExport {
  const RuntimeDebugLogExport({
    required this.createdAt,
    required this.lines,
    required this.bytes,
  });

  final DateTime createdAt;
  final List<String> lines;
  final List<int> bytes;
}

class DiagnosticBundleService {
  const DiagnosticBundleService({
    required VaultService vault,
    RuntimeCapabilities runtime = RuntimeCapabilities.current,
    PackageInfoLoader packageInfoLoader = PackageInfo.fromPlatform,
    CrashLastEventIdReader crashLastEventId = _readCrashLastEventId,
    DiagnosticLogTailReader? logTailReader,
    DiagnosticLogFileReader? logFileReader,
  }) : this._(
         vault,
         runtime,
         packageInfoLoader,
         crashLastEventId,
         logTailReader,
         logFileReader,
       );

  const DiagnosticBundleService._(
    this._vault,
    this._runtime,
    this._packageInfoLoader,
    this._crashLastEventId,
    this._logTailReader,
    this._logFileReader,
  );

  final VaultService _vault;
  final RuntimeCapabilities _runtime;
  final PackageInfoLoader _packageInfoLoader;
  final CrashLastEventIdReader _crashLastEventId;
  final DiagnosticLogTailReader? _logTailReader;
  final DiagnosticLogFileReader? _logFileReader;

  Future<DiagnosticBundle> buildRedactedBundle() async {
    final createdAt = DateTime.now().toUtc();
    final packageInfo = await _loadPackageInfo();
    final crashEventId = _lastNonEmptyCrashEventId();
    final logFiles = await _readDiagnosticLogFiles(createdAt: createdAt);
    final crashEventEntry = crashEventId == null
        ? null
        : <String, Object?>{'lastCrashEventId': crashEventId};
    final manifest = <String, Object?>{
      'formatVersion': 1,
      'createdAt': createdAt.toIso8601String(),
      'app': packageInfo.toDiagnosticJson(),
      'runtimeMode': _runtime.mode.name,
      'crashReporting': _runtime.crashReporting,
      'verboseRedactedLogging': _runtime.verboseRedactedLogging,
      'platform': Platform.operatingSystem,
      'platformVersion': Redactor.redact(Platform.operatingSystemVersion),
      'vaultState': _vault.state.name,
      'vaultInitialized': _vault.header != null,
      'localUnlockProtectors': _vault.header?.localUnlockProtectors.length ?? 0,
      'files': [
        const <String, Object?>{'path': 'manifest.json', 'kind': 'manifest'},
        for (final logFile in logFiles)
          <String, Object?>{
            'path': 'logs/${logFile.name}',
            'kind': 'redacted offline diagnostic log',
            'redacted': true,
            'bytes': logFile.bytes.length,
            'lines': logFile.lineCount,
          },
      ],
      'includedData': const [
        'app version and build metadata',
        'redacted runtime metadata',
        'last crash event id when available',
        'rotated redacted offline diagnostic logs',
      ],
      'excludedData': const [
        'terminal output',
        'commands',
        'hostnames',
        'usernames',
        'remote or local file paths',
        'credentials',
        'private keys',
      ],
      ...?crashEventEntry,
    };
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    return DiagnosticBundle(
      createdAt: createdAt,
      manifest: manifest,
      bytes: _buildZip([
        _ZipEntry(
          path: 'manifest.json',
          modifiedAt: createdAt,
          bytes: manifestBytes,
        ),
        for (final logFile in logFiles)
          _ZipEntry(
            path: 'logs/${logFile.name}',
            modifiedAt: createdAt,
            bytes: logFile.bytes,
          ),
      ]),
    );
  }

  Future<RuntimeDebugLogExport> buildRedactedRuntimeDebugLog() async {
    final createdAt = DateTime.now().toUtc();
    final lines = await _readRedactedLogTail();
    final contents = _runtimeDebugLogContents(
      createdAt: createdAt,
      lines: lines,
    );
    return RuntimeDebugLogExport(
      createdAt: createdAt,
      lines: lines,
      bytes: utf8.encode('$contents\n'),
    );
  }

  Future<DiagnosticAppInfo> _loadPackageInfo() async {
    try {
      final info = await _packageInfoLoader();
      return DiagnosticAppInfo(
        appName: info.appName,
        packageName: info.packageName,
        version: info.version,
        buildNumber: info.buildNumber,
        installerStore: info.installerStore,
        installTime: info.installTime,
        updateTime: info.updateTime,
      );
    } on Object {
      return const DiagnosticAppInfo.unavailable();
    }
  }

  String? _lastNonEmptyCrashEventId() {
    try {
      final eventId = _crashLastEventId().trim();
      return eventId.isEmpty || RegExp(r'^0+$').hasMatch(eventId)
          ? null
          : eventId;
    } on Object {
      return null;
    }
  }

  Future<List<String>> _readRedactedLogTail() async {
    final logTailReader = _logTailReader;
    if (logTailReader != null) {
      try {
        return [
          for (final line in await logTailReader()) Redactor.redact(line),
        ];
      } on Object {
        return const [];
      }
    }
    try {
      final files = await OfflineDiagnosticLogger().readLogFiles();
      if (files.isEmpty) {
        return const [];
      }
      final lines = <String>[
        for (final file in files)
          ...const LineSplitter().convert(utf8.decode(file.bytes)),
      ];
      final start = lines.length > 200 ? lines.length - 200 : 0;
      return [for (final line in lines.skip(start)) Redactor.redact(line)];
    } on Object {
      return const [];
    }
  }

  Future<List<DiagnosticLogFile>> _readDiagnosticLogFiles({
    required DateTime createdAt,
  }) async {
    final logFileReader = _logFileReader;
    try {
      final files = logFileReader == null
          ? await OfflineDiagnosticLogger().readLogFiles()
          : await logFileReader();
      final redacted = [
        for (final file in files)
          DiagnosticLogFile(
            name: _safeDiagnosticLogName(file.name),
            bytes: utf8.encode(Redactor.redact(utf8.decode(file.bytes))),
            lineCount: file.lineCount,
          ),
      ];
      if (redacted.isNotEmpty) {
        return redacted;
      }
    } on Object {
      // Fall through to the runtime-debug fallback below.
    }

    final lines = await _readRedactedLogTail();
    final fallbackContents =
        '${_runtimeDebugLogContents(createdAt: createdAt, lines: lines)}\n';
    return [
      DiagnosticLogFile(
        name: 'runtime-debug.log',
        bytes: utf8.encode(fallbackContents),
        lineCount: const LineSplitter().convert(fallbackContents).length,
      ),
    ];
  }
}

String _safeDiagnosticLogName(String value) {
  final name = value.split('/').last.split('\\').last.trim();
  if (name.isEmpty || name == '.' || name == '..') {
    return 'serlink.log';
  }
  return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

String _runtimeDebugLogContents({
  required DateTime createdAt,
  required List<String> lines,
}) {
  return [
    'Serlink Runtime Debug Log',
    'createdAt=${createdAt.toIso8601String()}',
    'redacted=true',
    'tailLines=${lines.length}',
    '',
    if (lines.isEmpty) 'No runtime debug log was found.' else ...lines,
  ].join('\n');
}

class _ZipEntry {
  const _ZipEntry({
    required this.path,
    required this.modifiedAt,
    required this.bytes,
  });

  final String path;
  final DateTime modifiedAt;
  final List<int> bytes;
}

List<int> _buildZip(List<_ZipEntry> entries) {
  final archive = BytesBuilder(copy: false);
  final centralDirectory = BytesBuilder(copy: false);
  var offset = 0;

  for (final entry in entries) {
    final pathBytes = utf8.encode(entry.path);
    final bytes = entry.bytes;
    final crc = _crc32(bytes);
    final time = _zipDosTime(entry.modifiedAt);
    final date = _zipDosDate(entry.modifiedAt);

    final localHeader = BytesBuilder(copy: false);
    _addUint32(localHeader, 0x04034b50);
    _addUint16(localHeader, 20);
    _addUint16(localHeader, 0);
    _addUint16(localHeader, 0);
    _addUint16(localHeader, time);
    _addUint16(localHeader, date);
    _addUint32(localHeader, crc);
    _addUint32(localHeader, bytes.length);
    _addUint32(localHeader, bytes.length);
    _addUint16(localHeader, pathBytes.length);
    _addUint16(localHeader, 0);
    localHeader.add(pathBytes);
    final localHeaderBytes = localHeader.takeBytes();
    archive.add(localHeaderBytes);
    archive.add(bytes);

    _addUint32(centralDirectory, 0x02014b50);
    _addUint16(centralDirectory, 20);
    _addUint16(centralDirectory, 20);
    _addUint16(centralDirectory, 0);
    _addUint16(centralDirectory, 0);
    _addUint16(centralDirectory, time);
    _addUint16(centralDirectory, date);
    _addUint32(centralDirectory, crc);
    _addUint32(centralDirectory, bytes.length);
    _addUint32(centralDirectory, bytes.length);
    _addUint16(centralDirectory, pathBytes.length);
    _addUint16(centralDirectory, 0);
    _addUint16(centralDirectory, 0);
    _addUint16(centralDirectory, 0);
    _addUint16(centralDirectory, 0);
    _addUint32(centralDirectory, 0);
    _addUint32(centralDirectory, offset);
    centralDirectory.add(pathBytes);

    offset += localHeaderBytes.length + bytes.length;
  }

  final centralDirectoryBytes = centralDirectory.takeBytes();
  final centralDirectoryOffset = offset;
  archive.add(centralDirectoryBytes);

  _addUint32(archive, 0x06054b50);
  _addUint16(archive, 0);
  _addUint16(archive, 0);
  _addUint16(archive, entries.length);
  _addUint16(archive, entries.length);
  _addUint32(archive, centralDirectoryBytes.length);
  _addUint32(archive, centralDirectoryOffset);
  _addUint16(archive, 0);

  return archive.takeBytes();
}

void _addUint16(BytesBuilder builder, int value) {
  builder.add([value & 0xff, (value >> 8) & 0xff]);
}

void _addUint32(BytesBuilder builder, int value) {
  builder.add([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}

int _zipDosTime(DateTime value) {
  final local = value.toLocal();
  return (local.hour << 11) | (local.minute << 5) | (local.second ~/ 2);
}

int _zipDosDate(DateTime value) {
  final local = value.toLocal();
  final year = local.year < 1980 ? 1980 : local.year;
  return ((year - 1980) << 9) | (local.month << 5) | local.day;
}

final List<int> _crc32Table = List<int>.generate(256, (index) {
  var crc = index;
  for (var bit = 0; bit < 8; bit += 1) {
    crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
  }
  return crc;
});

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc = _crc32Table[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

class DiagnosticAppInfo {
  const DiagnosticAppInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    this.installerStore,
    this.installTime,
    this.updateTime,
  });

  const DiagnosticAppInfo.unavailable()
    : appName = 'unknown',
      packageName = 'unknown',
      version = 'unknown',
      buildNumber = 'unknown',
      installerStore = null,
      installTime = null,
      updateTime = null;

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String? installerStore;
  final DateTime? installTime;
  final DateTime? updateTime;

  Map<String, Object?> toDiagnosticJson() {
    return {
      'appName': Redactor.redact(appName),
      'packageName': Redactor.redact(packageName),
      'version': version,
      'buildNumber': buildNumber,
      if (installerStore != null) 'installerStore': installerStore,
      if (installTime != null)
        'installTime': installTime!.toUtc().toIso8601String(),
      if (updateTime != null)
        'updateTime': updateTime!.toUtc().toIso8601String(),
    };
  }
}

String _readCrashLastEventId() => '';
