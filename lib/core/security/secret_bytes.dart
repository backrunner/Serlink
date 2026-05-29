import 'dart:typed_data';

class SecretBytes {
  SecretBytes(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  bool _destroyed = false;

  List<int> copyBytes() {
    if (_destroyed) {
      throw StateError('Secret bytes were destroyed.');
    }
    return List<int>.unmodifiable(_bytes);
  }

  void destroy() {
    _bytes.fillRange(0, _bytes.length, 0);
    _destroyed = true;
  }
}
