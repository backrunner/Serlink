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
    'windows' => _defaultWindowsShellProfile(env, exists),
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

/// Prefers PowerShell 7, then Windows PowerShell, then `%ComSpec%`, matching
/// the default profile order of Windows Terminal.
LocalShellProfile _defaultWindowsShellProfile(
  Map<String, String> environment,
  FileExists fileExists,
) {
  String? lookup(String name) => _nonEmpty(_windowsEnv(environment, name));

  final systemRoot = lookup('SystemRoot') ?? lookup('windir') ?? r'C:\Windows';
  final pathEntries = [
    for (final entry in (lookup('PATH') ?? '').split(';'))
      ?_trimWindowsDirectory(entry),
  ];
  final pwsh = _firstExisting([
    for (final root in {lookup('ProgramW6432'), lookup('ProgramFiles')})
      if (_trimWindowsDirectory(root ?? '') case final directory?)
        '$directory\\PowerShell\\7\\pwsh.exe',
    for (final directory in pathEntries) '$directory\\pwsh.exe',
  ], fileExists);
  final windowsPowerShell = _firstExisting([
    '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
  ], fileExists);
  final executable =
      pwsh ?? windowsPowerShell ?? lookup('ComSpec') ?? 'cmd.exe';
  final homeDrive = lookup('HOMEDRIVE');
  final userProfile =
      lookup('USERPROFILE') ??
      (homeDrive == null ? null : '$homeDrive${lookup('HOMEPATH') ?? ''}');
  return LocalShellProfile(
    executable: executable,
    arguments: executable == pwsh || executable == windowsPowerShell
        ? const ['-NoLogo']
        : const [],
    workingDirectory: userProfile,
    environment: _windowsShellEnvironment(environment),
  );
}

/// Windows tools rely on many per-user variables (APPDATA, TEMP, PSModulePath,
/// ProgramFiles, toolchain homes), so local shells inherit the user's
/// environment. Serlink's own variables are not passed on.
Map<String, String> _windowsShellEnvironment(Map<String, String> environment) {
  return {
    for (final entry in environment.entries)
      if (!entry.key.toUpperCase().startsWith('SERLINK_') &&
          !entry.key.startsWith('='))
        entry.key: entry.value,
  };
}

/// Windows variable names are case-insensitive; test maps are not.
String? _windowsEnv(Map<String, String> environment, String name) {
  final exact = environment[name];
  if (exact != null) {
    return exact;
  }
  final upper = name.toUpperCase();
  for (final entry in environment.entries) {
    if (entry.key.toUpperCase() == upper) {
      return entry.value;
    }
  }
  return null;
}

String? _trimWindowsDirectory(String value) {
  var trimmed = value.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    trimmed = trimmed.substring(1, trimmed.length - 1).trim();
  }
  while (trimmed.length > 3 &&
      (trimmed.endsWith(r'\') || trimmed.endsWith('/'))) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed.isEmpty ? null : trimmed;
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
