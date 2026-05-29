class SecretRef {
  const SecretRef(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is SecretRef && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

class SecretStoreCapabilities {
  const SecretStoreCapabilities({
    required this.available,
    required this.deviceLocal,
    required this.syncable,
    required this.biometricGate,
  });

  final bool available;
  final bool deviceLocal;
  final bool syncable;
  final bool biometricGate;
}

abstract interface class SecretStore {
  Future<SecretStoreCapabilities> capabilities();
  Future<void> write(SecretRef ref, List<int> value);
  Future<List<int>?> read(SecretRef ref);
  Future<void> delete(SecretRef ref);
}
