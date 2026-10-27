// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/src/hostkey/hostkey_rsa.dart';
import 'package:dartssh2/src/ssh_agent.dart';
import 'package:dartssh2/src/ssh_hostkey.dart';
import 'package:dartssh2/src/ssh_identity.dart';
import 'package:dartssh2/src/ssh_message.dart';
import 'package:ffi/ffi.dart';

abstract interface class SshAgentClient {
  List<SshAgentIdentity> listIdentities({String? socketPath});

  Uint8List sign({
    required Uint8List publicKeyBlob,
    required Uint8List data,
    required int flags,
    String? socketPath,
  });
}

class SshAgentIdentity {
  SshAgentIdentity({required Uint8List publicKeyBlob, required this.comment})
    : publicKeyBlob = Uint8List.fromList(publicKeyBlob);

  final Uint8List publicKeyBlob;
  final String comment;

  String get keyType => SSHHostKey.getType(publicKeyBlob);
}

class LocalSshAgentClient implements SshAgentClient {
  const LocalSshAgentClient({this.socketPath, this.responseTimeout});

  final String? socketPath;
  final Duration? responseTimeout;

  @override
  List<SshAgentIdentity> listIdentities({String? socketPath}) {
    final response = _send(
      _agentRequest((writer) {
        writer.writeUint8(SSHAgentProtocol.requestIdentities);
      }),
      socketPath: socketPath,
    );
    return _decodeAgentIdentities(response);
  }

  @override
  Uint8List sign({
    required Uint8List publicKeyBlob,
    required Uint8List data,
    required int flags,
    String? socketPath,
  }) {
    final response = _send(
      _agentRequest((writer) {
        writer.writeUint8(SSHAgentProtocol.signRequest);
        writer.writeString(publicKeyBlob);
        writer.writeString(data);
        writer.writeUint32(flags);
      }),
      socketPath: socketPath,
    );
    final reader = SSHMessageReader(response);
    final messageType = reader.readUint8();
    if (messageType == SSHAgentProtocol.failure) {
      throw const SshAgentException(
        'ssh_agent.sign_rejected',
        'SSH agent rejected the signing request.',
      );
    }
    if (messageType != SSHAgentProtocol.signResponse) {
      throw SshAgentException(
        'ssh_agent.unexpected_response',
        'SSH agent returned unexpected response $messageType.',
      );
    }
    return reader.readString();
  }

  Uint8List _send(Uint8List payload, {String? socketPath}) {
    final path = SshAgentSocketPathResolver.resolve(
      socketPath: socketPath ?? this.socketPath,
    );
    if (path == null || path.isEmpty) {
      throw const SshAgentException(
        'ssh_agent.socket_missing',
        'SSH_AUTH_SOCK is not available.',
      );
    }

    if (Platform.isWindows) {
      return _WindowsAgentPipe.exchange(
        path,
        payload,
        timeout: responseTimeout,
      );
    }
    int? fd;
    try {
      fd = _PosixUnixSocket.connect(path);
      final writer = SSHMessageWriter()..writeString(payload);
      _PosixUnixSocket.writeAll(fd, writer.takeBytes());
      final lengthBytes = _PosixUnixSocket.readExactly(fd, 4);
      final length = ByteData.sublistView(lengthBytes).getUint32(0);
      _validateAgentResponseLength(length);
      return _PosixUnixSocket.readExactly(fd, length);
    } on SocketException catch (error) {
      throw SshAgentException(
        'ssh_agent.socket_error',
        'SSH agent socket could not be used: ${error.message}',
      );
    } on SshAgentException {
      rethrow;
    } finally {
      if (fd != null) {
        _PosixUnixSocket.close(fd);
      }
    }
  }
}

List<SshAgentIdentity> _decodeAgentIdentities(Uint8List response) {
  final reader = SSHMessageReader(response);
  final messageType = reader.readUint8();
  if (messageType == SSHAgentProtocol.failure) {
    return const [];
  }
  if (messageType != SSHAgentProtocol.identitiesAnswer) {
    throw SshAgentException(
      'ssh_agent.unexpected_response',
      'SSH agent returned unexpected response $messageType.',
    );
  }
  final count = reader.readUint32();
  if (count > 2048) {
    throw const SshAgentException(
      'ssh_agent.invalid_length',
      'Too many agent identities.',
    );
  }
  return [
    for (var index = 0; index < count; index += 1)
      SshAgentIdentity(
        publicKeyBlob: reader.readString(),
        comment: reader.readUtf8(),
      ),
  ];
}

/// Identity enumeration uses bounded asynchronous IPC. It never requests a
/// signature, and a stale or non-agent socket cannot block the UI or discovery.
Future<List<SshAgentIdentity>> querySshAgentIdentities(
  String endpoint, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  if (Platform.isWindows) {
    return Isolate.run(
      () => LocalSshAgentClient(
        socketPath: endpoint,
        responseTimeout: timeout,
      ).listIdentities(),
    );
  }
  final socket = await Socket.connect(
    InternetAddress(endpoint, type: InternetAddressType.unix),
    0,
    timeout: timeout,
  );
  final input = StreamIterator<Uint8List>(socket);
  final bytes = <int>[];
  var offset = 0;
  Future<Uint8List> read(int count) async {
    while (bytes.length - offset < count) {
      if (!await input.moveNext()) {
        throw const SshAgentException(
          'ssh_agent.short_read',
          'Agent response ended early.',
        );
      }
      bytes.addAll(input.current);
      if (bytes.length > 1024 * 1024 + 4) {
        throw const SshAgentException(
          'ssh_agent.invalid_length',
          'Agent response is too large.',
        );
      }
    }
    final result = Uint8List.fromList(bytes.sublist(offset, offset + count));
    offset += count;
    return result;
  }

  try {
    final request = _agentRequest(
      (writer) => writer.writeUint8(SSHAgentProtocol.requestIdentities),
    );
    socket.add((SSHMessageWriter()..writeString(request)).takeBytes());
    return await (() async {
      final length = ByteData.sublistView(await read(4)).getUint32(0);
      _validateAgentResponseLength(length);
      return _decodeAgentIdentities(await read(length));
    })().timeout(timeout);
  } finally {
    socket.destroy();
    await input.cancel();
  }
}

class SshAgentSocketPathResolver {
  const SshAgentSocketPathResolver._();

  static String? resolve({String? socketPath}) {
    final explicit = socketPath?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      if (explicit.contains('\u0000')) {
        throw const SshAgentException(
          'ssh_agent.socket_error',
          'SSH agent endpoint contains an invalid character.',
        );
      }
      final home =
          Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
      if (explicit.startsWith('~/') && home != null) {
        return '$home/${explicit.substring(2)}';
      }
      return explicit;
    }
    if (Platform.isWindows) return r'\\.\pipe\openssh-ssh-agent';
    final environmentPath = Platform.environment['SSH_AUTH_SOCK'];
    if (environmentPath != null && environmentPath.isNotEmpty) {
      return environmentPath;
    }
    if (!Platform.isMacOS) {
      return null;
    }
    final result = Process.runSync('/bin/launchctl', [
      'getenv',
      'SSH_AUTH_SOCK',
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    final launchdPath = result.stdout.toString().trim();
    return launchdPath.isEmpty ? null : launchdPath;
  }
}

class SshAgentKeyPair implements SSHIdentity {
  SshAgentKeyPair({
    required this.identity,
    required this.agent,
    this.socketPath,
  });

  final SshAgentIdentity identity;
  final SshAgentClient agent;
  final String? socketPath;

  String get name => identity.keyType;

  @override
  String? get comment => identity.comment;

  @override
  bool get shouldProbe => true;

  @override
  String get type => switch (identity.keyType) {
    'ssh-rsa' => SSHRsaSignatureType.sha256,
    'ssh-rsa-cert-v01@openssh.com' => 'rsa-sha2-256-cert-v01@openssh.com',
    _ => identity.keyType,
  };

  int get _signatureFlags => switch (type) {
    SSHRsaSignatureType.sha256 => SSHAgentProtocol.rsaSha2_256,
    SSHRsaSignatureType.sha512 => SSHAgentProtocol.rsaSha2_512,
    'rsa-sha2-256-cert-v01@openssh.com' => SSHAgentProtocol.rsaSha2_256,
    _ => 0,
  };

  @override
  SSHHostKey toPublicKey() => _EncodedSshHostKey(identity.publicKeyBlob);

  @override
  FutureOr<SSHSignature> sign(Uint8List data) {
    final client = agent;
    if (client is LocalSshAgentClient) {
      final endpoint = socketPath ?? client.socketPath;
      final publicKeyBlob = identity.publicKeyBlob;
      final flags = _signatureFlags;
      // Approval may wait for a password manager, PIN or physical touch.
      // Keep the Flutter/SSH event loop responsive while the agent signs.
      return Isolate.run(
        () =>
            LocalSshAgentClient(socketPath: endpoint)
                .sign(publicKeyBlob: publicKeyBlob, data: data, flags: flags),
      ).then(_EncodedSshSignature.new);
    }
    return _EncodedSshSignature(
      agent.sign(
        publicKeyBlob: identity.publicKeyBlob,
        data: data,
        flags: _signatureFlags,
        socketPath: socketPath,
      ),
    );
  }

  String toPem() {
    throw UnsupportedError('Agent-backed SSH keys cannot be exported.');
  }
}

void _validateAgentResponseLength(int length) {
  if (length < 1 || length > 1024 * 1024) {
    throw const SshAgentException(
      'ssh_agent.invalid_length',
      'SSH agent response exceeds the allowed size.',
    );
  }
}

/// Windows OpenSSH and compatible agents use the same framed protocol over a
/// named pipe, rather than a Unix-domain socket.
final class _WindowsAgentPipe {
  static final _kernel = DynamicLibrary.open('kernel32.dll');
  static final _open = _kernel
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Utf16>,
          Uint32,
          Uint32,
          Pointer<Void>,
          Uint32,
          Uint32,
          Pointer<Void>,
        ),
        Pointer<Void> Function(
          Pointer<Utf16>,
          int,
          int,
          Pointer<Void>,
          int,
          int,
          Pointer<Void>,
        )
      >('CreateFileW');
  static final _read = _kernel
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Uint8>,
          Uint32,
          Pointer<Uint32>,
          Pointer<Void>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Uint8>,
          int,
          Pointer<Uint32>,
          Pointer<Void>,
        )
      >('ReadFile');
  static final _write = _kernel
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Uint8>,
          Uint32,
          Pointer<Uint32>,
          Pointer<Void>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Uint8>,
          int,
          Pointer<Uint32>,
          Pointer<Void>,
        )
      >('WriteFile');
  static final _close = _kernel
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('CloseHandle');

  static final _peek = _kernel
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Void>,
          Uint32,
          Pointer<Uint32>,
          Pointer<Uint32>,
          Pointer<Uint32>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Void>,
          int,
          Pointer<Uint32>,
          Pointer<Uint32>,
          Pointer<Uint32>,
        )
      >('PeekNamedPipe');

  static Uint8List exchange(
    String path,
    Uint8List payload, {
    Duration? timeout,
  }) {
    if (!path.toLowerCase().startsWith(r'\\.\pipe\')) {
      throw const SshAgentException(
        'ssh_agent.socket_error',
        'SSH agent must use a local Windows named pipe.',
      );
    }
    final name = path.toNativeUtf16();
    final handle = _open(name, 0xc0000000, 0, nullptr, 3, 0, nullptr);
    calloc.free(name);
    if (handle.address == -1 || handle.address == 0xffffffffffffffff) {
      throw const SshAgentException(
        'ssh_agent.socket_error',
        'SSH agent pipe could not be opened.',
      );
    }
    try {
      final deadline = timeout == null ? null : DateTime.now().add(timeout);
      final writer = SSHMessageWriter()..writeString(payload);
      _transfer(handle, writer.takeBytes(), writing: true);
      final header = Uint8List(4);
      _transfer(handle, header, writing: false, deadline: deadline);
      final length = ByteData.sublistView(header).getUint32(0);
      _validateAgentResponseLength(length);
      final response = Uint8List(length);
      _transfer(handle, response, writing: false, deadline: deadline);
      return response;
    } finally {
      _close(handle);
    }
  }

  static void _transfer(
    Pointer<Void> handle,
    Uint8List bytes, {
    required bool writing,
    DateTime? deadline,
  }) {
    final buffer = calloc<Uint8>(bytes.length);
    final count = calloc<Uint32>();
    final available = calloc<Uint32>();
    try {
      if (writing) buffer.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        var length = bytes.length - offset;
        if (!writing && deadline != null) {
          while (true) {
            if (_peek(handle, nullptr, 0, nullptr, available, nullptr) == 0) {
              throw const SshAgentException(
                'ssh_agent.socket_error',
                'Agent pipe is unavailable.',
              );
            }
            if (DateTime.now().isAfter(deadline)) {
              throw TimeoutException('Agent identity query timed out.');
            }
            if (available.value > 0) break;
            // Discovery runs in a worker isolate. Signing keeps its existing
            // unrestricted approval wait and does not use this deadline.
            sleep(const Duration(milliseconds: 10));
          }
          if (length > available.value) length = available.value;
        }
        final ok = (writing ? _write : _read)(
          handle,
          buffer + offset,
          length,
          count,
          nullptr,
        );
        if (ok == 0 || count.value == 0) {
          throw const SshAgentException(
            'ssh_agent.socket_error',
            'SSH agent pipe transfer failed.',
          );
        }
        offset += count.value;
      }
      if (!writing) bytes.setAll(0, buffer.asTypedList(bytes.length));
    } finally {
      calloc.free(buffer);
      calloc.free(count);
      calloc.free(available);
    }
  }
}

class _EncodedSshHostKey implements SSHHostKey {
  _EncodedSshHostKey(Uint8List value) : _value = Uint8List.fromList(value);

  final Uint8List _value;

  @override
  Uint8List encode() => Uint8List.fromList(_value);
}

class _EncodedSshSignature implements SSHSignature {
  _EncodedSshSignature(Uint8List value) : _value = Uint8List.fromList(value);

  final Uint8List _value;

  @override
  Uint8List encode() => Uint8List.fromList(_value);
}

Uint8List _agentRequest(void Function(SSHMessageWriter writer) build) {
  final writer = SSHMessageWriter();
  build(writer);
  return writer.takeBytes();
}

final class _PosixUnixSocket {
  const _PosixUnixSocket._();

  static final DynamicLibrary _libc = _openLibc();
  static final int Function(int domain, int type, int protocol) _socket = _libc
      .lookupFunction<
        Int32 Function(Int32 domain, Int32 type, Int32 protocol),
        int Function(int domain, int type, int protocol)
      >('socket');
  static final int Function(int fd, Pointer<Void> address, int length)
  _connect = _libc
      .lookupFunction<
        Int32 Function(Int32 fd, Pointer<Void> address, Uint32 length),
        int Function(int fd, Pointer<Void> address, int length)
      >('connect');
  static final int Function(int fd, Pointer<Void> buffer, int count) _read =
      _libc.lookupFunction<
        IntPtr Function(Int32 fd, Pointer<Void> buffer, UintPtr count),
        int Function(int fd, Pointer<Void> buffer, int count)
      >('read');
  static final int Function(int fd, Pointer<Void> buffer, int count) _write =
      _libc.lookupFunction<
        IntPtr Function(Int32 fd, Pointer<Void> buffer, UintPtr count),
        int Function(int fd, Pointer<Void> buffer, int count)
      >('write');
  static final int Function(int fd) _close = _libc
      .lookupFunction<Int32 Function(Int32 fd), int Function(int fd)>('close');

  static int connect(String path) {
    if (!Platform.isMacOS && !Platform.isLinux) {
      throw const SshAgentException(
        'ssh_agent.platform_unsupported',
        'SSH agent Unix sockets are supported on macOS and Linux only.',
      );
    }

    final fd = _socket(_afUnix, _sockStream, 0);
    if (fd < 0) {
      throw const SshAgentException(
        'ssh_agent.socket_error',
        'SSH agent socket could not be opened.',
      );
    }

    final pathBytes = utf8.encode(path);
    final ok = Platform.isMacOS
        ? _connectMacOS(fd, pathBytes)
        : _connectLinux(fd, pathBytes);
    if (!ok) {
      close(fd);
      throw const SshAgentException(
        'ssh_agent.socket_error',
        'SSH agent socket could not be connected.',
      );
    }
    return fd;
  }

  static void writeAll(int fd, Uint8List bytes) {
    final buffer = calloc<Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        final written = _write(
          fd,
          (buffer + offset).cast<Void>(),
          bytes.length - offset,
        );
        if (written <= 0) {
          throw const SshAgentException(
            'ssh_agent.short_write',
            'SSH agent socket could not write the full request.',
          );
        }
        offset += written;
      }
    } finally {
      calloc.free(buffer);
    }
  }

  static Uint8List readExactly(int fd, int length) {
    final result = Uint8List(length);
    final buffer = calloc<Uint8>(length);
    try {
      var offset = 0;
      while (offset < length) {
        final read = _read(fd, (buffer + offset).cast<Void>(), length - offset);
        if (read <= 0) {
          throw const SshAgentException(
            'ssh_agent.short_read',
            'SSH agent closed the socket unexpectedly.',
          );
        }
        offset += read;
      }
      result.setAll(0, buffer.asTypedList(length));
      return result;
    } finally {
      calloc.free(buffer);
    }
  }

  static void close(int fd) {
    _close(fd);
  }

  static bool _connectMacOS(int fd, List<int> pathBytes) {
    if (pathBytes.length >= _macOSPathLength) {
      return false;
    }
    final address = calloc<_SockAddrUnMacOS>();
    try {
      address.ref.sunLen = sizeOf<_SockAddrUnMacOS>();
      address.ref.sunFamily = _afUnix;
      for (var index = 0; index < pathBytes.length; index += 1) {
        address.ref.sunPath[index] = pathBytes[index];
      }
      address.ref.sunPath[pathBytes.length] = 0;
      return _connect(fd, address.cast<Void>(), sizeOf<_SockAddrUnMacOS>()) ==
          0;
    } finally {
      calloc.free(address);
    }
  }

  static bool _connectLinux(int fd, List<int> pathBytes) {
    if (pathBytes.length >= _linuxPathLength) {
      return false;
    }
    final address = calloc<_SockAddrUnLinux>();
    try {
      address.ref.sunFamily = _afUnix;
      for (var index = 0; index < pathBytes.length; index += 1) {
        address.ref.sunPath[index] = pathBytes[index];
      }
      address.ref.sunPath[pathBytes.length] = 0;
      return _connect(fd, address.cast<Void>(), sizeOf<_SockAddrUnLinux>()) ==
          0;
    } finally {
      calloc.free(address);
    }
  }
}

final class _SockAddrUnMacOS extends Struct {
  @Uint8()
  external int sunLen;

  @Uint8()
  external int sunFamily;

  @Array(_macOSPathLength)
  external Array<Uint8> sunPath;
}

final class _SockAddrUnLinux extends Struct {
  @Uint16()
  external int sunFamily;

  @Array(_linuxPathLength)
  external Array<Uint8> sunPath;
}

DynamicLibrary _openLibc() {
  if (Platform.isMacOS) {
    return DynamicLibrary.open('/usr/lib/libSystem.B.dylib');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libc.so.6');
  }
  return DynamicLibrary.process();
}

const _afUnix = 1;
const _sockStream = 1;
const _macOSPathLength = 104;
const _linuxPathLength = 108;

class SshAgentException implements Exception {
  const SshAgentException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SshAgentException($code): $message';
}
