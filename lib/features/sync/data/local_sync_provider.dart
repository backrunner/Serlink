import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/sync_provider.dart';

class LocalDirectorySyncProvider implements SyncProvider {
  LocalDirectorySyncProvider(this.rootDirectory);

  static const _manifestFileName = 'manifest.json';

  final Directory rootDirectory;

  @override
  Future<ProviderCapabilities> capabilities() async {
    return const ProviderCapabilities(
      kind: SyncProviderKind.local,
      supportsConditionalWrites: false,
      requiresTls: false,
    );
  }

  @override
  Future<RemoteManifest?> readManifest() async {
    final file = File(p.join(rootDirectory.path, _manifestFileName));
    if (!await file.exists()) {
      return null;
    }
    return RemoteManifest.fromBytes(await file.readAsBytes());
  }

  @override
  Future<void> writeManifest(RemoteManifest manifest) async {
    await rootDirectory.create(recursive: true);
    final file = File(p.join(rootDirectory.path, _manifestFileName));
    await file.writeAsBytes(manifest.toBytes(), flush: true);
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) async {
    await rootDirectory.create(recursive: true);
    final refs = <RemoteObjectRef>[];
    await for (final entity in rootDirectory.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relativePath = p
          .split(p.relative(entity.path, from: rootDirectory.path))
          .join('/');
      if (relativePath == _manifestFileName) {
        continue;
      }
      if (prefix != null && !relativePath.startsWith(prefix)) {
        continue;
      }
      refs.add(RemoteObjectRef(relativePath));
    }
    refs.sort((a, b) => a.path.compareTo(b.path));
    return refs;
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) async {
    final file = File(_objectPath(ref));
    if (!await file.exists()) {
      throw const SyncProviderException(
        'sync.provider.not_found',
        'Sync object was not found.',
      );
    }
    return file.readAsBytes();
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) async {
    await rootDirectory.create(recursive: true);
    final file = File(_objectPath(ref));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) async {
    final file = File(_objectPath(ref));
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _objectPath(RemoteObjectRef ref) {
    final relativePath = _safeRemoteObjectPath(ref.path);
    return p.joinAll([rootDirectory.path, ...relativePath.split('/')]);
  }
}

String _safeRemoteObjectPath(String path) {
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(r'\') ||
      path
          .split('/')
          .any(
            (segment) => segment.isEmpty || segment == '.' || segment == '..',
          )) {
    throw const SyncProviderException(
      'sync.provider.invalid_object_ref',
      'Sync object path is invalid.',
    );
  }
  return path;
}
