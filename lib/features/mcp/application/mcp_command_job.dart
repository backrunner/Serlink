import 'dart:async';
import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../ssh/application/ssh_session_service.dart';
import '../data/command_output_store.dart';

/// A non-PTY script on the existing SSH connection. Quiet output never means
/// completion: done requires channel closure AND drained stdout/stderr streams.
class McpCommandJob {
  McpCommandJob({
    required this.id,
    required this.sessionId,
    required this.process,
    required this.output,
    required this.commandBytes,
    required this.cwd,
    required this.display,
  });

  final String id;
  final SessionId sessionId;
  final SshCommandProcess process;
  final CommandOutputStore output;
  final int commandBytes;
  final String? cwd;
  final void Function(String) display;
  final startedAt = DateTime.now().toUtc();
  DateTime? finishedAt;
  int? exitCode;
  String? exitSignal;
  String? failure;
  bool cancelRequested = false;
  bool finished = false;
  bool _disposed = false;
  String? _command;
  Completer<void> _changed = Completer<void>();
  Future<void>? _completion;

  void start(String command, {required void Function() validateInput}) {
    _command = command;
    final stdout = _consume(process.stdout);
    final stderr = _consume(process.stderr);
    final input = _send(command, validateInput);
    _completion = _finish(stdout, stderr, input);
  }

  Future<void> _send(String command, void Function() validateInput) async {
    try {
      final bytes = utf8.encode(
        command.endsWith('\n') ? command : '$command\n',
      );
      for (var offset = 0; offset < bytes.length; offset += 32 * 1024) {
        if (_disposed || cancelRequested) break;
        validateInput();
        await process.write(
          bytes.sublist(offset, (offset + 32 * 1024).clamp(0, bytes.length)),
        );
      }
      await process.closeInput();
    } on Object {
      if (!cancelRequested && !_disposed && process.exitCode == null) {
        failure ??= 'command_input_failed';
        await cancel();
      }
    }
  }

  Future<void> _consume(Stream<List<int>> stream) async {
    try {
      await for (final text in const Utf8Decoder(
        allowMalformed: true,
      ).bind(stream)) {
        if (_disposed) continue;
        await output.append(text);
        display(text.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n'));
        _notify();
      }
    } on Object {
      if (!_disposed) {
        failure ??= 'command_output_unavailable';
        await cancel();
      }
    }
  }

  Future<void> _finish(
    Future<void> stdout,
    Future<void> stderr,
    Future<void> input,
  ) async {
    try {
      await process.done;
    } on Object {
      failure ??= 'command_channel_closed';
    }
    // Even an abnormal channel close can leave decoded data buffered locally.
    // Never publish finished until both readers and the input sender drain.
    try {
      await Future.wait([stdout, stderr, input]);
    } on Object {
      failure ??= 'command_output_unavailable';
    }
    exitCode = process.exitCode;
    exitSignal = process.exitSignal;
    finished = true;
    finishedAt = DateTime.now().toUtc();
    if (!_disposed) {
      display(
        '\r\n[Serlink command $id: $state${exitCode == null ? '' : ' ($exitCode)'}]\r\n',
      );
    }
    _notify();
  }

  String get state => !finished
      ? (cancelRequested ? 'cancel_requested' : 'running')
      : failure != null
      ? 'failed'
      : exitCode != null
      ? 'exited'
      : 'closed';

  Future<Map<String, Object?>> read({
    int cursor = 0,
    int maxChars = CommandOutputStore.pageSize,
    Duration wait = Duration.zero,
    bool commandSource = false,
  }) async {
    final length = commandSource ? (_command?.length ?? 0) : output.length;
    if (cursor < 0 || cursor > length) {
      throw const FormatException('invalid_output_cursor');
    }
    if (!commandSource &&
        cursor == output.length &&
        !finished &&
        wait > Duration.zero) {
      await Future.any<void>([_changed.future, Future<void>.delayed(wait)]);
    }
    final page = commandSource
        ? _readSource(cursor, maxChars)
        : await output.read(cursor: cursor, maxChars: maxChars);
    // More output may commit while this page is decrypted. In particular a
    // concurrent exit must not combine finished=true with stale hasMore=false.
    final total = commandSource ? (_command?.length ?? 0) : output.length;
    return {
      'commandId': id,
      'sessionId': sessionId.value,
      'mode': 'job',
      'view': commandSource ? 'command' : 'output',
      'state': state,
      'finished': finished,
      'exitCode': exitCode,
      'exitSignal': exitSignal,
      'commandBytes': commandBytes,
      'cwd': cwd,
      'shell': 'sh',
      'isolatedShell': true,
      'output': page.text,
      'cursor': page.cursor,
      'nextCursor': page.nextCursor,
      'totalChars': total,
      'hasMore': page.nextCursor < total,
      'outputTruncated': !commandSource && output.truncated,
      'outputLimitBytes': output.maxBytes,
      'cancelRequested': cancelRequested,
      'startedAt': startedAt.toIso8601String(),
      if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
      if (failure != null) 'error': failure,
    };
  }

  ({String text, int cursor, int nextCursor, int totalChars, bool hasMore})
  _readSource(int cursor, int maxChars) {
    final source = _command ?? '';
    var start = cursor;
    if (start > 0 &&
        start < source.length &&
        source.codeUnitAt(start) >= 0xdc00 &&
        source.codeUnitAt(start) <= 0xdfff) {
      start--;
    }
    var end = (start + maxChars.clamp(1, CommandOutputStore.pageSize)).clamp(
      0,
      source.length,
    );
    if (end < source.length &&
        end > start &&
        source.codeUnitAt(end - 1) >= 0xd800 &&
        source.codeUnitAt(end - 1) <= 0xdbff) {
      if (end == start + 1) {
        end++;
      } else {
        end--;
      }
    }
    return (
      text: source.substring(start, end),
      cursor: start,
      nextCursor: end,
      totalChars: source.length,
      hasMore: end < source.length,
    );
  }

  Future<void> cancel() async {
    if (finished || cancelRequested) return;
    cancelRequested = true;
    _notify();
    try {
      await process.interrupt().timeout(const Duration(seconds: 2));
    } on Object {
      /* Signal delivery is best effort; never claim completion. */
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
    try {
      await process.close().timeout(const Duration(seconds: 2));
    } on Object {
      /* The channel may already be gone. */
    }
    try {
      await _completion?.timeout(const Duration(seconds: 2));
    } on Object {
      /* Do not retain a dead job's encrypted output. */
    }
    await output.dispose();
    _command = null;
    _notify();
  }

  void _notify() {
    final previous = _changed;
    _changed = Completer<void>();
    if (!previous.isCompleted) previous.complete();
  }
}
