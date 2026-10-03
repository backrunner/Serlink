import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';

void main() {
  test('keeps UTF-8 text editable without replacing characters', () {
    const text = 'PORT=8080\n名称=服务\t🚀\r\n';
    final preview = SftpFilePreview.fromBytes(
      utf8.encode(text),
      truncated: false,
    );
    expect(preview.isText, isTrue);
    expect(preview.text, text);
    expect(preview.bytesRead, utf8.encode(text).length);
  });

  for (final bytes in [
    [0x50, 0x4b, 3, 4], // ZIP
    [0, 0x61, 0, 0x62], // UTF-16 requires an external reader.
    [0xff, 0xd8, 0xff], // JPEG
    [0x61, 0xc3, 0x28], // Malformed UTF-8
    utf8.encode('%PDF-1.7\n'), // Even an ASCII-only PDF is not editable text.
  ]) {
    test('rejects non-text preview $bytes', () {
      final preview = SftpFilePreview.fromBytes(bytes, truncated: false);
      expect(preview.isText, isFalse);
      expect(preview.text, isEmpty);
    });
  }

  test('accepts every truncated UTF-8 tail without corrupting the preview', () {
    for (final character in ['é', '中', '🚀']) {
      final encoded = utf8.encode(character);
      for (var tail = 1; tail < encoded.length; tail++) {
        final preview = SftpFilePreview.fromBytes([
          ...utf8.encode('hello '),
          ...encoded.take(tail),
        ], truncated: true);
        expect(preview.isText, isTrue);
        expect(preview.text, 'hello ');
        expect(preview.truncated, isTrue);
      }
    }
  });

  test('does not excuse malformed bytes inside a truncated preview', () {
    final preview = SftpFilePreview.fromBytes([
      0xc3,
      0x28,
      0x61,
    ], truncated: true);
    expect(preview.isText, isFalse);
  });
}
