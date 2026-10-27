import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/ids/entity_id.dart';
import '../sftp/application/sftp_connection.dart';
import '../sftp/domain/sftp_entry.dart';
import '../ssh/application/ssh_session_service.dart';
import '../ssh/domain/connection_profile.dart';
import 'demo_file_system.dart';
import 'demo_shell.dart';

class DemoSshService implements SshSessionService {
  final Map<HostId, DemoFileSystem> fileSystems = {};
  final Map<SessionId, DemoShell> _shells = {};
  DemoFileSystem filesFor(HostId id) =>
      fileSystems.putIfAbsent(id, DemoFileSystem.new);
  @override
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile) async {
    final shell = DemoShell(filesFor(profile.hostId));
    _shells[profile.sessionId] = shell;
    unawaited(shell.done.then((_) => _shells.remove(profile.sessionId)));
    return shell;
  }

  @override
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile) async =>
      DemoSftpConnection(filesFor(profile.hostId));
  @override
  Future<void> testConnection(ConnectionProfileSnapshot profile) async {}
  @override
  Future<bool> probeShell({required SessionId sessionId}) async =>
      _shells.containsKey(sessionId);
  Never _realForwardRequired() => throw UnsupportedError(
    'Port forwarding requires the real review server. Offline demo creates no network listeners.',
  );
  @override
  Future<void> startLocalForward({
    required SessionId sessionId,
    required int localPort,
    required String remoteHost,
    required int remotePort,
  }) async => _realForwardRequired();
  @override
  Future<void> stopLocalForward({required SessionId sessionId}) async {}
  @override
  Future<RemoteForwardBinding> startRemoteForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
    required String localHost,
    required int localPort,
  }) async => _realForwardRequired();
  @override
  Future<void> stopRemoteForward({required SessionId sessionId}) async {}
  @override
  Future<DynamicForwardBinding> startDynamicForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
  }) async => _realForwardRequired();
  @override
  Future<void> stopDynamicForward({required SessionId sessionId}) async {}
  Future<void> dispose() async {
    await Future.wait(_shells.values.toList().map((shell) => shell.close()));
    _shells.clear();
    fileSystems.clear();
  }
}

class DemoSftpConnection implements SftpConnection {
  DemoSftpConnection(this.files);
  final DemoFileSystem files;
  final _closed = Completer<void>();
  void _check() {
    if (_closed.isCompleted) {
      throw const FileSystemException('Demo connection is closed');
    }
  }

  String _path(String path) {
    _check();
    return files.resolve(path);
  }

  @override
  Future<void> get done => _closed.future;
  @override
  Future<List<SftpEntry>> list(String path) async => files.list(_path(path));
  @override
  Future<void> mkdir(String path) async => files.mkdir(_path(path));
  @override
  Future<void> rename(String oldPath, String newPath) async =>
      files.rename(_path(oldPath), _path(newPath));
  @override
  Future<void> deleteFile(String path) async {
    final normalized = _path(path);
    if (!files.files.containsKey(normalized)) {
      throw const FileSystemException('Not a file');
    }
    files.remove(normalized);
  }

  @override
  Future<void> deleteDirectory(String path, {required bool recursive}) async {
    final normalized = _path(path);
    if (!files.directories.contains(normalized)) {
      throw const FileSystemException('Not a directory');
    }
    files.remove(normalized, recursive: recursive);
  }

  @override
  Future<void> chmod(String path, SftpPermissions permissions) async {
    final normalized = _path(path);
    if (!files.exists(normalized)) {
      throw const FileSystemException('No such file');
    }
    files.modes[normalized] = permissions;
  }

  @override
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  }) async {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes);
    final bytes = files.read(_path(path));
    return SftpFilePreview.fromBytes(
      bytes.take(maxBytes).toList(),
      truncated: bytes.length > maxBytes,
    );
  }

  @override
  Future<void> writeTextFile(String path, String contents) async =>
      files.write(_path(path), utf8.encode(contents));

  @override
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) async* {
    final destination = _path(remotePath);
    yield TransferProgress(
      taskId: taskId,
      state: TransferState.running,
      transferredBytes: 0,
    );
    var transferred = 0;
    if (itemKind == TransferItemKind.file) {
      final file = File(localPath);
      if (await file.length() > DemoFileSystem.maxBytes) {
        throw const FileSystemException('Demo upload limit is 16 MiB');
      }
      final bytes = await file.readAsBytes();
      _check();
      files.write(destination, bytes);
      transferred = bytes.length;
    } else {
      if (!files.directories.contains(destination)) files.mkdir(destination);
      await for (final entry in Directory(
        localPath,
      ).list(recursive: true, followLinks: false)) {
        _check();
        final relative = p.relative(entry.path, from: localPath);
        final target = files.resolve(
          p.posix.join(destination, p.split(relative).join('/')),
        );
        if (!target.startsWith('$destination/')) {
          throw const FileSystemException('Invalid upload path');
        }
        if (entry is Directory) {
          if (!files.directories.contains(target)) files.mkdir(target);
        }
        if (entry is File) {
          if (await entry.length() > DemoFileSystem.maxBytes) {
            throw const FileSystemException('Demo upload limit is 16 MiB');
          }
          final bytes = await entry.readAsBytes();
          _check();
          files.write(target, bytes);
          transferred += bytes.length;
        }
      }
    }
    _check();
    yield TransferProgress(
      taskId: taskId,
      state: TransferState.completed,
      transferredBytes: transferred,
      totalBytes: transferred,
    );
  }

  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) async* {
    final source = _path(remotePath);
    yield TransferProgress(
      taskId: taskId,
      state: TransferState.running,
      transferredBytes: 0,
    );
    var transferred = 0;
    if (itemKind == TransferItemKind.file) {
      final bytes = files.read(source);
      await File(localPath).writeAsBytes(bytes, flush: true);
      transferred = bytes.length;
    } else {
      if (!files.directories.contains(source)) {
        throw const FileSystemException('No such directory');
      }
      await Directory(localPath).create(recursive: true);
      Future<void> copy(String path, String local) async {
        for (final entry in files.list(path)) {
          _check();
          final target = p.join(local, entry.name);
          if (entry.type == SftpEntryType.directory) {
            await Directory(target).create();
            await copy(entry.path, target);
          } else {
            final bytes = files.read(entry.path);
            await File(target).writeAsBytes(bytes, flush: true);
            transferred += bytes.length;
          }
        }
      }

      await copy(source, localPath);
    }
    _check();
    yield TransferProgress(
      taskId: taskId,
      state: TransferState.completed,
      transferredBytes: transferred,
      totalBytes: transferred,
    );
  }

  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
  }
}
