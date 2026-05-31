import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/sync_provider.dart';

/// Encrypted-snapshot sync backed by the user's private CloudKit database.
///
/// Bridges to native macOS via the `serlink/cloudkit` method channel. Each
/// remote object (including the manifest) is stored as a CloudKit record keyed
/// by its relative path; payloads are opaque encrypted bytes.
class CloudKitSyncProvider implements SyncProvider {
  CloudKitSyncProvider({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  static const _defaultChannel = MethodChannel('serlink/cloudkit');
  static const _manifestKey = 'manifest.json';

  final MethodChannel _channel;

  static Future<bool> isAvailable({MethodChannel? channel}) async {
    if (!Platform.isMacOS) {
      return false;
    }
    try {
      return await (channel ?? _defaultChannel).invokeMethod<bool>(
            'isAvailable',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<ProviderCapabilities> capabilities() async {
    return const ProviderCapabilities(
      kind: SyncProviderKind.cloudKit,
      supportsConditionalWrites: false,
      requiresTls: false,
    );
  }

  @override
  Future<RemoteManifest?> readManifest() async {
    final bytes = await _readObjectOrNull(_manifestKey);
    return bytes == null ? null : RemoteManifest.fromBytes(bytes);
  }

  @override
  Future<void> writeManifest(RemoteManifest manifest) async {
    await writeObject(const RemoteObjectRef(_manifestKey), manifest.toBytes());
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) async {
    final paths = await _invoke<List<Object?>>('listObjects', {
      'prefix': prefix,
    });
    return [
      for (final path in paths ?? const [])
        if (path is String && path != _manifestKey) RemoteObjectRef(path),
    ]..sort((a, b) => a.path.compareTo(b.path));
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) async {
    final bytes = await _readObjectOrNull(ref.path);
    if (bytes == null) {
      throw const SyncProviderException(
        'sync.provider.not_found',
        'CloudKit object was not found.',
      );
    }
    return bytes;
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) async {
    await _invoke<void>('writeObject', {
      'path': ref.path,
      'data': Uint8List.fromList(bytes),
    });
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) async {
    await _invoke<void>('deleteObject', {'path': ref.path});
  }

  Future<List<int>?> _readObjectOrNull(String path) async {
    final data = await _invoke<Uint8List?>('readObject', {'path': path});
    return data;
  }

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw const SyncProviderException(
        'sync.cloudkit.unavailable',
        'iCloud sync is only available on macOS.',
      );
    } on PlatformException catch (error) {
      throw SyncProviderException(
        error.code.startsWith('sync.') ? error.code : 'sync.cloudkit.failed',
        error.message ?? 'iCloud sync failed.',
        diagnostic: error.details?.toString(),
      );
    }
  }
}
