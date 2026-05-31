part of 'workspace_smoke_test.dart';

class _LockedVaultHarness {
  const _LockedVaultHarness({
    required this.database,
    required this.recoveryKey,
  });

  final SerlinkDatabase database;
  final VaultRecoveryKey recoveryKey;
}

class _FakeSshSessionService implements SshSessionService {
  final _MutableFakeSftpConnection sftp = _MutableFakeSftpConnection();
  final _FakeShellSession shell = _FakeShellSession();
  final List<String> remoteBindings = [];
  final List<String> dynamicBindings = [];

  @override
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile) async {
    return shell;
  }

  @override
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile) async {
    return sftp;
  }

  @override
  Future<void> startLocalForward({
    required SessionId sessionId,
    required int localPort,
    required String remoteHost,
    required int remotePort,
  }) async {}

  @override
  Future<void> stopLocalForward({required SessionId sessionId}) async {}

  @override
  Future<RemoteForwardBinding> startRemoteForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
    required String localHost,
    required int localPort,
  }) async {
    remoteBindings.add('$bindHost:$bindPort->$localHost:$localPort');
    return RemoteForwardBinding(
      bindHost: bindHost,
      bindPort: bindPort,
      localHost: localHost,
      localPort: localPort,
    );
  }

  @override
  Future<void> stopRemoteForward({required SessionId sessionId}) async {}

  @override
  Future<DynamicForwardBinding> startDynamicForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
  }) async {
    dynamicBindings.add('$bindHost:$bindPort');
    return DynamicForwardBinding(bindHost: bindHost, bindPort: bindPort);
  }

  @override
  Future<void> stopDynamicForward({required SessionId sessionId}) async {}

  @override
  Future<void> testConnection(ConnectionProfileSnapshot profile) async {}
}

class _FakeShellSession implements SshShellSession {
  final List<String> writes = [];
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> get done => _done.future;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Future<void> close() async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  }) async {}

  @override
  Future<void> write(List<int> bytes) async {
    writes.add(String.fromCharCodes(bytes));
  }
}

class _MutableFakeSftpConnection implements SftpConnection {
  final Set<String> deniedListPaths = {};
  final Map<String, SftpEntry> _entries = {
    '/app.env': SftpEntry(
      name: 'app.env',
      path: '/app.env',
      type: SftpEntryType.file,
      size: 2400,
      modifiedAt: DateTime.utc(2026, 1, 2, 3, 4),
      permissions: const SftpPermissions('0640'),
      owner: 'deploy',
      group: 'ops',
    ),
    '/.hidden.env': SftpEntry(
      name: '.hidden.env',
      path: '/.hidden.env',
      type: SftpEntryType.file,
      size: 128,
      modifiedAt: DateTime.utc(2026, 1, 2, 3, 5),
      permissions: const SftpPermissions('0600'),
      owner: 'deploy',
      group: 'ops',
      isHidden: true,
    ),
    '/home/ops/home.env': SftpEntry(
      name: 'home.env',
      path: '/home/ops/home.env',
      type: SftpEntryType.file,
      size: 512,
      modifiedAt: DateTime.utc(2026, 1, 2, 3, 6),
      permissions: const SftpPermissions('0640'),
      owner: 'deploy',
      group: 'ops',
    ),
  };
  final Map<String, String> _fileContents = {
    '/app.env': 'PORT=8080\n',
    '/home/ops/home.env': 'HOME=true\n',
  };
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> chmod(String path, SftpPermissions permissions) async {
    final entry = _entries[path]!;
    _entries[path] = SftpEntry(
      name: entry.name,
      path: entry.path,
      type: entry.type,
      size: entry.size,
      modifiedAt: entry.modifiedAt,
      permissions: permissions,
      owner: entry.owner,
      group: entry.group,
      isHidden: entry.isHidden,
    );
  }

  @override
  Future<void> close() async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> deleteDirectory(String path, {required bool recursive}) async {
    _entries.remove(path);
  }

  @override
  Future<void> deleteFile(String path) async {
    _entries.remove(path);
    _fileContents.remove(path);
  }

  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) {
    return Stream<TransferProgress>.value(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: _entries[remotePath]?.size ?? 1,
        totalBytes: _entries[remotePath]?.size ?? 1,
      ),
    );
  }

  @override
  Future<List<SftpEntry>> list(String path) async {
    if (deniedListPaths.contains(path)) {
      throw const SftpFailureException(
        SftpFailure(
          code: SftpFailureCode.permissionDenied,
          message: 'Permission denied by the remote server.',
        ),
      );
    }
    return [
      for (final entry in _entries.values)
        if (_parentOf(entry.path) == path) entry,
    ];
  }

  @override
  Future<void> mkdir(String path) async {
    _entries[path] = SftpEntry(
      name: path.split('/').last,
      path: path,
      type: SftpEntryType.directory,
      permissions: const SftpPermissions('0755'),
    );
  }

  @override
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  }) async {
    final text = _fileContents[path] ?? '';
    final bytes = text.codeUnits.length;
    if (bytes <= maxBytes) {
      return SftpFilePreview(text: text, bytesRead: bytes, truncated: false);
    }
    return SftpFilePreview(
      text: text.substring(0, maxBytes),
      bytesRead: maxBytes,
      truncated: true,
    );
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {
    final entry = _entries.remove(oldPath)!;
    final contents = _fileContents.remove(oldPath);
    if (contents != null) {
      _fileContents[newPath] = contents;
    }
    _entries[newPath] = SftpEntry(
      name: newPath.split('/').last,
      path: newPath,
      type: entry.type,
      size: entry.size,
      modifiedAt: entry.modifiedAt,
      permissions: entry.permissions,
      owner: entry.owner,
      group: entry.group,
      isHidden: entry.isHidden,
    );
  }

  @override
  Future<void> writeTextFile(String path, String contents) async {
    _fileContents[path] = contents;
    final entry = _entries[path]!;
    _entries[path] = SftpEntry(
      name: entry.name,
      path: entry.path,
      type: entry.type,
      size: contents.codeUnits.length,
      modifiedAt: entry.modifiedAt,
      permissions: entry.permissions,
      owner: entry.owner,
      group: entry.group,
      isHidden: entry.isHidden,
    );
  }

  @override
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) {
    return Stream<TransferProgress>.value(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: 1,
        totalBytes: 1,
      ),
    );
  }
}

String _parentOf(String path) {
  final index = path.lastIndexOf('/');
  if (index <= 0) {
    return '/';
  }
  return path.substring(0, index);
}
