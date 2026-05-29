import 'dart:io';

import '../../ssh/application/ssh_session_service.dart';

class LocalShellProfile {
  const LocalShellProfile({
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
    this.environment = const {},
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
}

abstract interface class LocalTerminalService {
  Future<SshShellSession> openShell({int columns = 80, int rows = 24});
}

class LocalTerminalException implements Exception {
  const LocalTerminalException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'LocalTerminalException($code): $message';
}

typedef FileExists = bool Function(String path);

LocalShellProfile defaultLocalShellProfile({
  String operatingSystem = '',
  Map<String, String>? environment,
  FileExists? fileExists,
}) {
  final env = environment ?? Platform.environment;
  final os = operatingSystem.isEmpty
      ? Platform.operatingSystem
      : operatingSystem;
  final exists = fileExists ?? ((path) => File(path).existsSync());
  return switch (os) {
    'windows' => _defaultWindowsShellProfile(env),
    'macos' => _defaultMacOsShellProfile(env, exists),
    _ => _defaultUnixShellProfile(env, exists),
  };
}

LocalShellProfile _defaultMacOsShellProfile(
  Map<String, String> environment,
  FileExists fileExists,
) {
  final executable = _firstExisting([
    '/bin/zsh',
    environment['SHELL'],
    '/bin/bash',
    '/bin/sh',
  ], fileExists);
  if (executable == null) {
    throw const LocalTerminalException(
      'local_terminal.shell_missing',
      'No local shell executable was found.',
    );
  }
  return LocalShellProfile(
    executable: executable,
    arguments: executable == '/bin/zsh' ? const ['-l', '-i'] : const [],
    workingDirectory: _nonEmpty(environment['HOME']),
    environment: _shellEnvironment(environment, executable),
  );
}

LocalShellProfile _defaultUnixShellProfile(
  Map<String, String> environment,
  FileExists fileExists,
) {
  final executable = _firstExisting([
    environment['SHELL'],
    '/bin/zsh',
    '/bin/bash',
    '/bin/sh',
  ], fileExists);
  if (executable == null) {
    throw const LocalTerminalException(
      'local_terminal.shell_missing',
      'No local shell executable was found.',
    );
  }
  return LocalShellProfile(
    executable: executable,
    workingDirectory: _nonEmpty(environment['HOME']),
    environment: _shellEnvironment(environment, executable),
  );
}

LocalShellProfile _defaultWindowsShellProfile(Map<String, String> environment) {
  final comSpec = _nonEmpty(environment['ComSpec']) ?? 'cmd.exe';
  final homeDrive = _nonEmpty(environment['HOMEDRIVE']);
  final userProfile =
      _nonEmpty(environment['USERPROFILE']) ??
      (homeDrive == null ? null : '$homeDrive${environment['HOMEPATH'] ?? ''}');
  return LocalShellProfile(
    executable: comSpec,
    workingDirectory: userProfile,
    environment: _filteredShellEnvironment(environment),
  );
}

String? _firstExisting(List<String?> candidates, FileExists fileExists) {
  for (final candidate in candidates) {
    final path = _nonEmpty(candidate);
    if (path != null && fileExists(path)) {
      return path;
    }
  }
  return null;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

Map<String, String> _filteredShellEnvironment(Map<String, String> environment) {
  return {
    for (final key in const [
      'HOME',
      'USER',
      'USERNAME',
      'LOGNAME',
      'PATH',
      'SHELL',
      'TERM',
      'LANG',
      'LC_ALL',
      'LC_CTYPE',
      'DISPLAY',
      'ComSpec',
      'SystemRoot',
      'USERPROFILE',
      'HOMEDRIVE',
      'HOMEPATH',
    ])
      if (_nonEmpty(environment[key]) != null) key: environment[key]!,
  };
}

Map<String, String> _shellEnvironment(
  Map<String, String> environment,
  String executable,
) {
  return {..._filteredShellEnvironment(environment), 'SHELL': executable};
}
