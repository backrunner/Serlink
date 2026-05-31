import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:xterm/xterm.dart';

import '../application/terminal_zmodem_transfer.dart';

class FileSelectorTerminalZModemTransferHandler
    implements TerminalZModemTransferHandler {
  const FileSelectorTerminalZModemTransferHandler();

  @override
  Future<bool> receiveOffer(ZModemOffer offer) async {
    final location = await getSaveLocation(
      suggestedName: _safeFileName(offer.info.pathname),
      confirmButtonText: 'Receive',
      canCreateDirectories: true,
    );
    if (location == null || location.path.isEmpty) {
      offer.skip();
      return false;
    }

    final output = File(location.path);
    final sink = output.openWrite();
    try {
      await sink.addStream(offer.accept(0));
    } finally {
      await sink.close();
    }

    final modificationTime = offer.info.modificationTime;
    if (modificationTime != null && modificationTime > 0) {
      try {
        await output.setLastModified(
          DateTime.fromMillisecondsSinceEpoch(modificationTime * 1000),
        );
      } on Object {
        // File contents are the transfer result; timestamp preservation is best
        // effort because some platforms/locations can reject metadata changes.
      }
    }
    return true;
  }

  @override
  Future<Iterable<ZModemOffer>> requestFiles() async {
    final files = await openFiles(confirmButtonText: 'Send');
    final offers = <ZModemOffer>[];
    for (final file in files) {
      offers.add(
        ZModemCallbackOffer(
          ZModemFileInfo(
            pathname: _safeFileName(_displayName(file)),
            length: await file.length(),
            modificationTime: await _modificationTimeSeconds(file),
          ),
          onAccept: file.openRead,
        ),
      );
    }
    return offers;
  }

  Future<int?> _modificationTimeSeconds(XFile file) async {
    final path = file.path;
    if (path.isEmpty) {
      return null;
    }
    try {
      final stat = await File(path).stat();
      return stat.modified.millisecondsSinceEpoch ~/ 1000;
    } on Object {
      return null;
    }
  }
}

String _displayName(XFile file) {
  if (file.name.trim().isNotEmpty) {
    return file.name;
  }
  if (file.path.trim().isNotEmpty) {
    return file.path;
  }
  return 'zmodem-upload';
}

String _safeFileName(String pathname) {
  final normalized = pathname.replaceAll(r'\', '/');
  final name = p.basename(normalized).trim();
  if (name.isEmpty || name == '.' || name == '..') {
    return 'zmodem-file';
  }
  return name;
}
