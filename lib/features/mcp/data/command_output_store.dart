import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../../../core/security/local_file_security.dart';

/// Private, ephemeral encrypted output. Only the in-memory key can read a job;
/// no plaintext command output is written to disk or included in diagnostics.
class CommandOutputStore {
  CommandOutputStore._(
    this.directory,
    this._file,
    this._writer,
    this._key,
    this.maxBytes,
  );

  static final _cipher = AesGcm.with256bits();
  static const pageSize = 64 * 1024;
  static const defaultMaxBytes = 256 * 1024 * 1024;
  final Directory directory;
  final File _file;
  final RandomAccessFile _writer;
  final SecretKey _key;
  final int maxBytes;
  final _records = <({int start, int chars, int position, int bytes})>[];
  Future<void> _pending = Future<void>.value();
  int length = 0;
  int capturedBytes = 0;
  int _fileLength = 0;
  bool truncated = false;
  bool _disposed = false;

  static Future<CommandOutputStore> create({
    int maxBytes = defaultMaxBytes,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'serlink-command-output-',
    );
    try {
      await LocalFileSecurity.preparePrivateDirectory(directory);
      final file = File('${directory.path}/output.enc');
      await LocalFileSecurity.restrictFile(file);
      return CommandOutputStore._(
        directory,
        file,
        await file.open(mode: FileMode.write),
        await _cipher.newSecretKey(),
        maxBytes,
      );
    } on Object {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> append(String text) {
    final result = _pending.then((_) async {
      if (_disposed || truncated) return;
      for (var start = 0; start < text.length;) {
        var end = (start + 32 * 1024).clamp(0, text.length);
        if (end < text.length && _high(text.codeUnitAt(end - 1))) end--;
        final part = text.substring(start, end);
        final bytes = utf8.encode(part);
        if (capturedBytes + bytes.length > maxBytes) {
          truncated = true;
          return;
        }
        final box = await _cipher.encrypt(bytes, secretKey: _key);
        final encrypted = box.concatenation();
        await _writer.writeFrom(encrypted);
        _records.add((
          start: length,
          chars: part.length,
          position: _fileLength,
          bytes: encrypted.length,
        ));
        length += part.length;
        capturedBytes += bytes.length;
        _fileLength += encrypted.length;
        start = end;
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<
    ({String text, int cursor, int nextCursor, int totalChars, bool hasMore})
  >
  read({required int cursor, int maxChars = pageSize}) async {
    await _pending;
    if (_disposed || cursor < 0 || cursor > length) {
      throw const FormatException('invalid_output_cursor');
    }
    final total = length;
    final limit = maxChars.clamp(1, pageSize);
    final selected = _records
        .where(
          (r) => r.start + r.chars > cursor && r.start < cursor + limit + 1,
        )
        .toList();
    if (selected.isEmpty) {
      return (
        text: '',
        cursor: cursor,
        nextCursor: cursor,
        totalChars: total,
        hasMore: false,
      );
    }
    final reader = await _file.open();
    try {
      final text = StringBuffer();
      for (final record in selected) {
        await reader.setPosition(record.position);
        final encrypted = await reader.read(record.bytes);
        final plain = await _cipher.decrypt(
          SecretBox.fromConcatenation(
            encrypted,
            nonceLength: 12,
            macLength: 16,
          ),
          secretKey: _key,
        );
        text.write(utf8.decode(plain));
      }
      final joined = text.toString();
      var offset = cursor - selected.first.start;
      // Cursors returned by this store never split a Unicode surrogate pair.
      // Also repair a caller-supplied cursor instead of emitting invalid UTF-16.
      if (offset > 0 &&
          offset < joined.length &&
          _low(joined.codeUnitAt(offset))) {
        offset--;
      }
      var end = (offset + limit).clamp(0, joined.length);
      if (end < joined.length &&
          end > offset &&
          _high(joined.codeUnitAt(end - 1))) {
        if (end == offset + 1) {
          end++;
        } else {
          end--;
        }
      }
      final actual = selected.first.start + offset;
      final next = selected.first.start + end;
      return (
        text: joined.substring(offset, end),
        cursor: actual,
        nextCursor: next,
        totalChars: total,
        hasMore: next < total,
      );
    } finally {
      await reader.close();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _pending;
    await _writer.close();
    await directory.delete(recursive: true);
    _records.clear();
  }

  static bool _high(int value) => value >= 0xd800 && value <= 0xdbff;
  static bool _low(int value) => value >= 0xdc00 && value <= 0xdfff;
}
