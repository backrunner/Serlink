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
      final relativePath = p.relative(entity.path, from: rootDirectory.path);
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
    return File(p.join(rootDirectory.path, ref.path)).readAsBytes();
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) async {
    await rootDirectory.create(recursive: true);
    final file = File(p.join(rootDirectory.path, ref.path));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) async {
    final file = File(p.join(rootDirectory.path, ref.path));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
