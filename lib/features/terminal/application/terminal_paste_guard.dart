import 'dart:async';

typedef MultilinePasteConfirmation = Future<bool> Function(String preview);

class TerminalPasteGuard {
  const TerminalPasteGuard({
    this.confirmMultilinePaste,
    this.previewLimit = 1200,
  });

  final MultilinePasteConfirmation? confirmMultilinePaste;
  final int previewLimit;

  Future<bool> allow(String data) async {
    if (!needsConfirmation(data)) {
      return true;
    }
    final confirm = confirmMultilinePaste;
    if (confirm == null) {
      return true;
    }
    return confirm(preview(data, limit: previewLimit));
  }

  static bool needsConfirmation(String data) {
    final payload = _pastePayload(data);
    final normalized = _normalizeLineEndings(payload);
    final withoutTrailingNewlines = normalized.replaceFirst(
      RegExp(r'\n+$'),
      '',
    );
    return withoutTrailingNewlines.contains('\n');
  }

  static String preview(String data, {int limit = 1200}) {
    final payload = _pastePayload(data);
    final normalized = _normalizeLineEndings(payload);
    if (normalized.length <= limit) {
      return normalized;
    }
    return '${normalized.substring(0, limit)}\n...';
  }

  static String _pastePayload(String data) {
    const start = '\x1b[200~';
    const end = '\x1b[201~';
    final startIndex = data.indexOf(start);
    if (startIndex == -1) {
      return data;
    }
    final payloadStart = startIndex + start.length;
    final endIndex = data.indexOf(end, payloadStart);
    if (endIndex == -1) {
      return data.substring(payloadStart);
    }
    return data.substring(payloadStart, endIndex);
  }

  static String _normalizeLineEndings(String data) {
    return data.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }
}
