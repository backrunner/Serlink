import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
// Exercise the wire protocol used by the vendored xterm implementation.
// ignore: depend_on_referenced_packages
import 'package:zmodem/zmodem.dart' show ZModemCore;

void main() {
  for (final acceptBeforeClose in [false, true]) {
    test(
      'closing a receive offer is safe (accepted=$acceptBeforeClose)',
      () async {
        final input = StreamController<Uint8List>();
        final output = StreamController<List<int>>();
        final peer = ZModemCore()..initiateSend();
        final ready = Completer<void>();
        final subscription = output.stream.listen((bytes) {
          peer.receive(_wireBytes(Uint8List.fromList(bytes))).toList();
          if (!ready.isCompleted) ready.complete();
        });
        final mux = ZModemMux(stdin: output, stdout: input.stream);
        final offered = Completer<ZModemOffer>();
        mux.onFileOffer = offered.complete;
        StreamSubscription<Uint8List>? receive;
        addTearDown(() async {
          await receive?.cancel();
          await mux.close();
          await input.close();
          await output.close();
          await subscription.cancel();
        });

        input.add(_wireBytes(peer.dataToSend()));
        await ready.future.timeout(const Duration(seconds: 1));
        peer.offerFile(ZModemFileInfo(pathname: 'example.txt', length: 4));
        input.add(peer.dataToSend());
        final offer = await offered.future.timeout(const Duration(seconds: 1));
        if (acceptBeforeClose) {
          receive = offer.accept(0).listen((_) {})..pause();
        }
        await mux.close().timeout(const Duration(seconds: 1));
        if (!acceptBeforeClose) {
          offer.skip();
          expect(await offer.accept(0).toList(), isEmpty);
        }
      },
    );
  }

  test('closing while file selection is pending ignores late offers', () async {
    final input = StreamController<Uint8List>();
    final output = StreamController<List<int>>();
    final writes = <List<int>>[];
    final subscription = output.stream.listen(writes.add);
    final mux = ZModemMux(stdin: output, stdout: input.stream);
    addTearDown(() async {
      await mux.close();
      await input.close();
      await output.close();
      await subscription.cancel();
    });
    final requested = Completer<void>();
    final selection = Completer<Iterable<ZModemOffer>>();
    mux.onFileRequest = () {
      requested.complete();
      return selection.future;
    };
    final peer = ZModemCore()..initiateReceive();
    final header = _wireBytes(peer.dataToSend());
    // The handshake can span arbitrary SSH chunks.
    input.add(Uint8List.sublistView(header, 0, 1));
    input.add(Uint8List.sublistView(header, 1));
    await requested.future.timeout(const Duration(seconds: 1));
    await mux.close();
    final count = writes.length;
    selection.complete(const []);
    await Future<void>.delayed(Duration.zero);
    expect(writes, hasLength(count));
  });
}

Uint8List _wireBytes(Uint8List bytes) {
  // Match lrzsz's high-bit LF, which the zmodem parser requires.
  for (var i = 1; i < bytes.length; i++) {
    if (bytes[i - 1] == 0x0d && bytes[i] == 0x0a) bytes[i] = 0x8a;
  }
  return bytes;
}
