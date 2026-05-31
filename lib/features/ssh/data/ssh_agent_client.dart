// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/src/hostkey/hostkey_rsa.dart';
import 'package:dartssh2/src/ssh_agent.dart';
import 'package:dartssh2/src/ssh_hostkey.dart';
import 'package:dartssh2/src/ssh_key_pair.dart';
import 'package:dartssh2/src/ssh_message.dart';
import 'package:ffi/ffi.dart';

abstract interface class SshAgentClient {
  List<SshAgentIdentity> listIdentities();

  Uint8List sign({
    required Uint8List publicKeyBlob,
    required Uint8List data,
    required int flags,
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
  const LocalSshAgentClient({this.socketPath});

  final String? socketPath;

  @override
  List<SshAgentIdentity> listIdentities() {
    final response = _send(
      _agentRequest((writer) {
        writer.writeUint8(SSHAgentProtocol.requestIdentities);
      }),
    );
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
    return [
      for (var index = 0; index < count; index += 1)
        SshAgentIdentity(
          publicKeyBlob: reader.readString(),
          comment: reader.readUtf8(),
        ),
    ];
  }

  @override
  Uint8List sign({
    required Uint8List publicKeyBlob,
    required Uint8List data,
    required int flags,
  }) {
    final response = _send(
      _agentRequest((writer) {
        writer.writeUint8(SSHAgentProtocol.signRequest);
        writer.writeString(publicKeyBlob);
        writer.writeString(data);
        writer.writeUint32(flags);
      }),
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

  Uint8List _send(Uint8List payload) {
    final path = socketPath ?? SshAgentSocketPathResolver.resolve();
    if (path == null || path.isEmpty) {
      throw const SshAgentException(
        'ssh_agent.socket_missing',
        'SSH_AUTH_SOCK is not available.',
      );
    }

    int? fd;
    try {
      fd = _PosixUnixSocket.connect(path);
      final writer = SSHMessageWriter()..writeString(payload);
      _PosixUnixSocket.writeAll(fd, writer.takeBytes());
      final lengthBytes = _PosixUnixSocket.readExactly(fd, 4);
      final length = ByteData.sublistView(lengthBytes).getUint32(0);
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

class SshAgentSocketPathResolver {
  const SshAgentSocketPathResolver._();

  static String? resolve() {
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

class SshAgentKeyPair implements SSHKeyPair {
  SshAgentKeyPair({required this.identity, required this.agent});

  final SshAgentIdentity identity;
  final SshAgentClient agent;

  @override
  String get name => identity.keyType;

  @override
  String get type => switch (identity.keyType) {
    'ssh-rsa' => SSHRsaSignatureType.sha256,
    _ => identity.keyType,
  };

  int get _signatureFlags => switch (type) {
    SSHRsaSignatureType.sha256 => SSHAgentProtocol.rsaSha2_256,
    SSHRsaSignatureType.sha512 => SSHAgentProtocol.rsaSha2_512,
    _ => 0,
  };

  @override
  SSHHostKey toPublicKey() => _EncodedSshHostKey(identity.publicKeyBlob);

  @override
  SSHSignature sign(Uint8List data) {
    return _EncodedSshSignature(
      agent.sign(
        publicKeyBlob: identity.publicKeyBlob,
        data: data,
        flags: _signatureFlags,
      ),
    );
  }

  @override
  String toPem() {
    throw UnsupportedError('Agent-backed SSH keys cannot be exported.');
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
