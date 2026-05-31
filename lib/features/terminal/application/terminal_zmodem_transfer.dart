import 'package:xterm/xterm.dart';

abstract interface class TerminalZModemTransferHandler {
  Future<bool> receiveOffer(ZModemOffer offer);

  Future<Iterable<ZModemOffer>> requestFiles();
}
