part of 'workspace_tab_controller_test.dart';

class _FakeLocalTerminalService implements LocalTerminalService {
  final List<_FakeShellSession> shells = [];
  var openShellCount = 0;

  @override
  Future<SshShellSession> openShell({int columns = 80, int rows = 24}) async {
    openShellCount += 1;
    final shell = _FakeShellSession();
    shells.add(shell);
    return shell;
  }
}

class _FailingLocalTerminalService implements LocalTerminalService {
  const _FailingLocalTerminalService(this.error);

  final Object error;

  @override
  Future<SshShellSession> openShell({int columns = 80, int rows = 24}) async {
    throw error;
  }
}

Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 8; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeSshSessionService implements SshSessionService {
  final List<_FakeShellSession> shells = [];
  final List<Object> shellFailures = [];
  var openShellCount = 0;
  var openSftpCount = 0;

  @override
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile) async {
    openShellCount += 1;
    if (shellFailures.isNotEmpty) {
      throw shellFailures.removeAt(0);
    }
    final shell = _FakeShellSession();
    shells.add(shell);
    return shell;
  }

  @override
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile) async {
    openSftpCount += 1;
    return _FakeSftpConnection();
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
    return DynamicForwardBinding(bindHost: bindHost, bindPort: bindPort);
  }

  @override
  Future<void> stopDynamicForward({required SessionId sessionId}) async {}

  @override
  Future<void> testConnection(ConnectionProfileSnapshot profile) async {}
}

class _FakeShellSession implements SshShellSession {
  final Completer<void> _done = Completer<void>();
  final List<String> writes = [];

  void completeDone() {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Future<void> close() async {
    completeDone();
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

class _FakeSftpConnection implements SftpConnection {
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> chmod(String path, SftpPermissions permissions) async {}

  @override
  Future<void> close() async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> deleteDirectory(String path, {required bool recursive}) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) {
    return const Stream<TransferProgress>.empty();
  }

  @override
  Future<List<SftpEntry>> list(String path) async => [];

  @override
  Future<void> mkdir(String path) async {}

  @override
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  }) async {
    return const SftpFilePreview(text: '', bytesRead: 0, truncated: false);
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {}

  @override
  Future<void> writeTextFile(String path, String contents) async {}

  @override
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) {
    return const Stream<TransferProgress>.empty();
  }
}

class _FakeTerminalHostDisplaySettingsRepository
    implements TerminalHostDisplaySettingsRepository {
  _FakeTerminalHostDisplaySettingsRepository([
    Map<HostId, TerminalDisplaySettings>? profiles,
  ]) : profiles = {...?profiles};

  final Map<HostId, TerminalDisplaySettings> profiles;
  var readCount = 0;

  @override
  Future<void> deleteForHost(HostId hostId) async {
    profiles.remove(hostId);
  }

  @override
  Future<TerminalDisplaySettings?> readForHost(HostId hostId) async {
    readCount += 1;
    return profiles[hostId];
  }

  @override
  Future<void> saveForHost(
    HostId hostId,
    TerminalDisplaySettings settings,
  ) async {
    profiles[hostId] = settings;
  }
}

class _FakeTerminalDisplaySettingsRepository
    implements TerminalDisplaySettingsRepository {
  TerminalDisplaySettings? settings;

  @override
  Future<void> delete() async {
    settings = null;
  }

  @override
  Future<TerminalDisplaySettings?> read() async {
    return settings;
  }

  @override
  Future<void> save(TerminalDisplaySettings settings) async {
    this.settings = settings;
  }
}
