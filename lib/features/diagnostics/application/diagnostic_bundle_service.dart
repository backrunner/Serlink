import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/logging/redactor.dart';
import '../../../core/runtime/runtime_mode.dart';
import '../../vault/application/vault_service.dart';

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef SentryLastEventIdReader = SentryId Function();
typedef DiagnosticLogTailReader = Future<List<String>> Function();

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
    SentryLastEventIdReader sentryLastEventId = _readSentryLastEventId,
    DiagnosticLogTailReader? logTailReader,
  }) : this._(
         vault,
         runtime,
         packageInfoLoader,
         sentryLastEventId,
         logTailReader,
       );

  const DiagnosticBundleService._(
    this._vault,
    this._runtime,
    this._packageInfoLoader,
    this._sentryLastEventId,
    this._logTailReader,
  );

  final VaultService _vault;
  final RuntimeCapabilities _runtime;
  final PackageInfoLoader _packageInfoLoader;
  final SentryLastEventIdReader _sentryLastEventId;
  final DiagnosticLogTailReader? _logTailReader;

  Future<DiagnosticBundle> buildRedactedBundle() async {
    final createdAt = DateTime.now().toUtc();
    final packageInfo = await _loadPackageInfo();
    final sentryEventId = _lastNonEmptySentryEventId();
    final sentryEventEntry = sentryEventId == null
        ? null
        : <String, Object?>{'lastSentryEventId': sentryEventId};
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
      'includedData': const [
        'app version and build metadata',
        'redacted runtime metadata',
        'last Sentry event id when available',
        'redacted diagnostic log tail when present',
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
      ...?sentryEventEntry,
    };
    final logs = await _readRedactedLogTail();
    final bundle = <String, Object?>{
      'manifest': manifest,
      if (logs.isNotEmpty) 'logs': logs,
    };
    return DiagnosticBundle(
      createdAt: createdAt,
      manifest: manifest,
      bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(bundle)),
    );
  }

  Future<RuntimeDebugLogExport> buildRedactedRuntimeDebugLog() async {
    final createdAt = DateTime.now().toUtc();
    final lines = await _readRedactedLogTail();
    final contents = [
      'Serlink Runtime Debug Log',
      'createdAt=${createdAt.toIso8601String()}',
      'redacted=true',
      'tailLines=${lines.length}',
      '',
      if (lines.isEmpty) 'No runtime debug log was found.' else ...lines,
    ].join('\n');
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

  String? _lastNonEmptySentryEventId() {
    try {
      final eventId = _sentryLastEventId().toString();
      return RegExp(r'^0+$').hasMatch(eventId) ? null : eventId;
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
      final appDir = await getApplicationSupportDirectory();
      final logFile = File('${appDir.path}/Serlink/logs/serlink.log');
      if (!await logFile.exists()) {
        return const [];
      }
      final lines = await logFile.readAsLines();
      final start = lines.length > 200 ? lines.length - 200 : 0;
      return [for (final line in lines.skip(start)) Redactor.redact(line)];
    } on Object {
      return const [];
    }
  }
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

SentryId _readSentryLastEventId() => Sentry.lastEventId;
