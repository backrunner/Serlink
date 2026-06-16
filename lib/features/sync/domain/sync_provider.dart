import 'dart:convert';

enum SyncProviderKind { local, webDav, cloudKit, iCloudDrive }

class RemoteObjectRef {
  const RemoteObjectRef(this.path);

  final String path;
}

class RemoteManifest {
  const RemoteManifest({
    required this.vaultId,
    required this.protocolVersion,
    required this.encryptedPayload,
  });

  final String vaultId;
  final int protocolVersion;
  final List<int> encryptedPayload;

  Map<String, Object?> toJson() {
    return {
      'vaultId': vaultId,
      'protocolVersion': protocolVersion,
      'encryptedPayload': base64Encode(encryptedPayload),
    };
  }

  factory RemoteManifest.fromJson(Map<String, Object?> json) {
    return RemoteManifest(
      vaultId: json['vaultId'] as String,
      protocolVersion: json['protocolVersion'] as int,
      encryptedPayload: base64Decode(json['encryptedPayload'] as String),
    );
  }

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  factory RemoteManifest.fromBytes(List<int> bytes) {
    try {
      return RemoteManifest.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
      );
    } on Object {
      throw const SyncProviderException(
        'sync.provider.manifest_invalid',
        'Remote sync manifest is invalid.',
      );
    }
  }
}

class ProviderCapabilities {
  const ProviderCapabilities({
    required this.kind,
    required this.supportsConditionalWrites,
    required this.requiresTls,
  });

  final SyncProviderKind kind;
  final bool supportsConditionalWrites;
  final bool requiresTls;
}

abstract interface class SyncProvider {
  Future<ProviderCapabilities> capabilities();
  Future<RemoteManifest?> readManifest();
  Future<void> writeManifest(RemoteManifest manifest);
  Future<void> writeManifestIfUnchanged(
    RemoteManifest manifest,
    RemoteManifest? expectedCurrent,
  );

  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix});
  Future<List<int>> readObject(RemoteObjectRef ref);
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes);
  Future<void> deleteObject(RemoteObjectRef ref);
}

class SyncProviderException implements Exception {
  const SyncProviderException(
    this.code,
    this.message, {
    this.statusCode,
    this.diagnostic,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? diagnostic;

  @override
  String toString() {
    final status = statusCode == null ? '' : ', statusCode: $statusCode';
    final diagnostic = this.diagnostic == null
        ? ''
        : ', diagnostic: ${this.diagnostic}';
    return 'SyncProviderException($code$status$diagnostic): $message';
  }
}
