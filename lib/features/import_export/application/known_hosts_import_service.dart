import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../hosts/application/host_repository.dart';
import '../../hosts/domain/host.dart';
import '../../ssh/application/known_host_repository.dart';

class KnownHostsImportWarning {
  const KnownHostsImportWarning({
    required this.lineNumber,
    required this.code,
    required this.message,
  });

  final int lineNumber;
  final String code;
  final String message;
}

class KnownHostsImportResult {
  const KnownHostsImportResult({
    required this.entriesParsed,
    required this.recordsImported,
    required this.unmatchedHosts,
    required this.skippedLines,
    required this.warnings,
  });

  final int entriesParsed;
  final int recordsImported;
  final int unmatchedHosts;
  final int skippedLines;
  final List<KnownHostsImportWarning> warnings;
}

class KnownHostsImportService {
  KnownHostsImportService({
    required HostRepository hosts,
    required KnownHostRepository knownHosts,
    DateTime Function()? now,
  }) : this._(hosts, knownHosts, now ?? DateTime.now);

  KnownHostsImportService._(this._hosts, this._knownHosts, this._now);

  final HostRepository _hosts;
  final KnownHostRepository _knownHosts;
  final DateTime Function() _now;

  Future<KnownHostsImportResult> importText(String contents) async {
    final knownHosts = _parseKnownHosts(contents);
    final hostConfigs = await _hosts.list();
    var recordsImported = 0;
    var unmatchedHosts = 0;

    for (final entry in knownHosts.entries) {
      final matches = _matchingHosts(entry.targets, hostConfigs);
      if (matches.isEmpty) {
        unmatchedHosts += entry.targets.length;
        continue;
      }
      for (final host in matches) {
        final now = _now().toUtc();
        final existing = await _knownHosts.read(host.id);
        await _knownHosts.save(
          KnownHostRecord(
            hostId: host.id,
            hostname: host.hostname,
            port: host.port,
            algorithm: entry.algorithm,
            fingerprint: entry.fingerprint,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
        recordsImported += 1;
      }
    }

    return KnownHostsImportResult(
      entriesParsed: knownHosts.entries.length,
      recordsImported: recordsImported,
      unmatchedHosts: unmatchedHosts,
      skippedLines: knownHosts.skippedLines,
      warnings: knownHosts.warnings,
    );
  }
}

_KnownHostsParseResult _parseKnownHosts(String contents) {
  final entries = <_KnownHostsEntry>[];
  final warnings = <KnownHostsImportWarning>[];
  var skippedLines = 0;
  final lines = const LineSplitter().convert(contents);
  for (var index = 0; index < lines.length; index += 1) {
    final lineNumber = index + 1;
    final line = lines[index].trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final fields = line.split(RegExp(r'\s+'));
    final hasMarker = fields.first.startsWith('@');
    final hostIndex = hasMarker ? 1 : 0;
    final algorithmIndex = hasMarker ? 2 : 1;
    final keyIndex = hasMarker ? 3 : 2;
    if (fields.length <= keyIndex) {
      skippedLines += 1;
      warnings.add(
        KnownHostsImportWarning(
          lineNumber: lineNumber,
          code: 'known_hosts.invalid_line',
          message: 'Line $lineNumber is not a valid known_hosts entry.',
        ),
      );
      continue;
    }

    if (hasMarker) {
      skippedLines += 1;
      warnings.add(
        KnownHostsImportWarning(
          lineNumber: lineNumber,
          code: 'known_hosts.marker_unsupported',
          message:
              'Line $lineNumber uses ${fields.first}, which is not imported yet.',
        ),
      );
      continue;
    }

    final targets = _parseTargets(fields[hostIndex], lineNumber, warnings);
    if (targets.isEmpty) {
      skippedLines += 1;
      continue;
    }

    final keyBlob = _decodeKey(fields[keyIndex], lineNumber, warnings);
    if (keyBlob == null) {
      skippedLines += 1;
      continue;
    }

    entries.add(
      _KnownHostsEntry(
        targets: targets,
        algorithm: fields[algorithmIndex],
        fingerprint: _formatMd5Fingerprint(keyBlob),
      ),
    );
  }

  return _KnownHostsParseResult(
    entries: entries,
    skippedLines: skippedLines,
    warnings: warnings,
  );
}

List<_KnownHostsTarget> _parseTargets(
  String value,
  int lineNumber,
  List<KnownHostsImportWarning> warnings,
) {
  final targets = <_KnownHostsTarget>[];
  for (final rawTarget in value.split(',')) {
    final target = rawTarget.trim();
    if (target.isEmpty) {
      continue;
    }
    if (target.startsWith('|')) {
      warnings.add(
        KnownHostsImportWarning(
          lineNumber: lineNumber,
          code: 'known_hosts.hashed_host_unsupported',
          message: 'Line $lineNumber contains a hashed host entry.',
        ),
      );
      continue;
    }
    if (target.startsWith('!') ||
        target.contains('*') ||
        target.contains('?')) {
      warnings.add(
        KnownHostsImportWarning(
          lineNumber: lineNumber,
          code: 'known_hosts.pattern_unsupported',
          message: 'Line $lineNumber contains a host pattern.',
        ),
      );
      continue;
    }
    targets.add(_parseTarget(target));
  }
  return targets;
}

_KnownHostsTarget _parseTarget(String target) {
  if (target.startsWith('[')) {
    final closing = target.indexOf(']');
    final portPrefix = closing == -1 ? -1 : closing + 1;
    if (closing > 1 &&
        target.length > portPrefix + 1 &&
        target[portPrefix] == ':') {
      final port = int.tryParse(target.substring(portPrefix + 1));
      if (port != null) {
        return _KnownHostsTarget(
          hostname: target.substring(1, closing).toLowerCase(),
          port: port,
        );
      }
    }
  }
  return _KnownHostsTarget(hostname: target.toLowerCase(), port: 22);
}

Uint8List? _decodeKey(
  String value,
  int lineNumber,
  List<KnownHostsImportWarning> warnings,
) {
  try {
    return base64Decode(value);
  } on FormatException {
    warnings.add(
      KnownHostsImportWarning(
        lineNumber: lineNumber,
        code: 'known_hosts.key_invalid',
        message: 'Line $lineNumber contains an invalid host key.',
      ),
    );
    return null;
  }
}

List<HostConfig> _matchingHosts(
  List<_KnownHostsTarget> targets,
  List<HostConfig> hosts,
) {
  final matches = <HostConfig>[];
  for (final host in hosts) {
    final hostname = host.hostname.toLowerCase();
    if (targets.any(
      (target) => target.hostname == hostname && target.port == host.port,
    )) {
      matches.add(host);
    }
  }
  return matches;
}

String _formatMd5Fingerprint(Uint8List keyBlob) {
  final digest = MD5Digest().process(keyBlob);
  final bytes = [
    for (final byte in digest) byte.toRadixString(16).padLeft(2, '0'),
  ];
  return 'MD5:${bytes.join(':')}';
}

class _KnownHostsParseResult {
  const _KnownHostsParseResult({
    required this.entries,
    required this.skippedLines,
    required this.warnings,
  });

  final List<_KnownHostsEntry> entries;
  final int skippedLines;
  final List<KnownHostsImportWarning> warnings;
}

class _KnownHostsEntry {
  const _KnownHostsEntry({
    required this.targets,
    required this.algorithm,
    required this.fingerprint,
  });

  final List<_KnownHostsTarget> targets;
  final String algorithm;
  final String fingerprint;
}

class _KnownHostsTarget {
  const _KnownHostsTarget({required this.hostname, required this.port});

  final String hostname;
  final int port;
}
