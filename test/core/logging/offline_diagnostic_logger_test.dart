import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/logging/offline_diagnostic_logger.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'serlink-offline-log-test-',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('redacts entries and segments bounded daily offline logs', () async {
    var tick = 0;
    final logger = OfflineDiagnosticLogger(
      directoryProvider: () async => tempDir,
      now: () => DateTime.utc(2026, 6, 27, 10, 0, tick++),
      maxFileBytes: 360,
      maxRetentionDays: 5,
      maxLineBytes: 1024,
    );

    for (var index = 0; index < 18; index += 1) {
      await logger.record(
        'sync.push.success',
        details: {
          'index': index,
          'hostname': 'secret.example.test',
          'password': 'hunter2',
          'recordsUploaded': 1,
        },
      );
    }

    final files = await logger.readLogFiles();
    expect(files, isNotEmpty);
    expect(files.length, greaterThan(1));
    expect(files.map((file) => file.name), contains('serlink-2026-06-27.log'));
    expect(
      files.map((file) => file.name),
      everyElement(startsWith('serlink-2026-06-27')),
    );
    for (final file in files) {
      expect(file.bytes.length, lessThanOrEqualTo(360));
      expect(file.lineCount, greaterThan(0));
    }

    final serialized = utf8.decode([for (final file in files) ...file.bytes]);
    expect(serialized, contains('sync.push.success'));
    expect(serialized, contains('[redacted]'));
    expect(serialized, isNot(contains('hunter2')));
    expect(serialized, isNot(contains('secret.example.test')));
  });

  test('keeps only the most recent five log days', () async {
    late DateTime currentDate;
    final logger = OfflineDiagnosticLogger(
      directoryProvider: () async => tempDir,
      now: () => currentDate,
      maxFileBytes: 4096,
      maxRetentionDays: 5,
      maxLineBytes: 1024,
    );

    for (var day = 1; day <= 6; day += 1) {
      currentDate = DateTime.utc(2026, 6, day, 10);
      await logger.record('sync.run.success', details: {'day': day});
    }

    final files = await logger.readLogFiles();
    final names = files.map((file) => file.name).toList();

    expect(names, isNot(contains('serlink-2026-06-01.log')));
    expect(names, contains('serlink-2026-06-02.log'));
    expect(names, contains('serlink-2026-06-06.log'));
    expect(names.length, 5);
  });

  test('removes legacy numeric rotation logs during pruning', () async {
    final legacyActive = File('${tempDir.path}/serlink.log');
    final legacyRotated = File('${tempDir.path}/serlink.log.1');
    await legacyActive.writeAsString('legacy active');
    await legacyRotated.writeAsString('legacy rotated');

    final logger = OfflineDiagnosticLogger(
      directoryProvider: () async => tempDir,
      now: () => DateTime.utc(2026, 6, 27, 10),
    );

    await logger.record('sync.run.success');

    expect(await legacyActive.exists(), isFalse);
    expect(await legacyRotated.exists(), isFalse);
    expect(
      (await logger.readLogFiles()).map((file) => file.name),
      contains('serlink-2026-06-27.log'),
    );
  });
}
