enum SftpEntryType { file, directory, symlink, unknown }

class SftpPermissions {
  const SftpPermissions(this.octal);

  factory SftpPermissions.fromOctal(String octal) {
    final normalized = _normalizeOctalPermissions(octal);
    if (normalized == null) {
      throw FormatException('Invalid octal permissions: $octal');
    }
    return SftpPermissions(normalized);
  }

  static SftpPermissions? tryParse(String input) {
    final trimmed = input.trim();
    final normalizedOctal = _normalizeOctalPermissions(trimmed);
    if (normalizedOctal != null) {
      return SftpPermissions(normalizedOctal);
    }
    final symbolicOctal = _octalFromSymbolicPermissions(trimmed);
    if (symbolicOctal != null) {
      return SftpPermissions(symbolicOctal);
    }
    return null;
  }

  final String octal;

  String get normalizedOctal => _normalizeOctalPermissions(octal) ?? octal;

  String get symbolic =>
      _symbolicPermissionsFromOctal(normalizedOctal) ?? octal;
}

class SftpEntry {
  const SftpEntry({
    required this.name,
    required this.path,
    required this.type,
    this.size,
    this.modifiedAt,
    this.permissions,
    this.owner,
    this.group,
    this.isHidden = false,
  });

  final String name;
  final String path;
  final SftpEntryType type;
  final int? size;
  final DateTime? modifiedAt;
  final SftpPermissions? permissions;
  final String? owner;
  final String? group;
  final bool isHidden;
}

String? _normalizeOctalPermissions(String value) {
  if (!RegExp(r'^[0-7]{3,4}$').hasMatch(value)) {
    return null;
  }
  return value.length == 3 ? '0$value' : value;
}

String? _symbolicPermissionsFromOctal(String value) {
  final normalized = _normalizeOctalPermissions(value);
  if (normalized == null) {
    return null;
  }
  final special = int.parse(normalized[0], radix: 8);
  return [
    _symbolicPermissionTriplet(
      int.parse(normalized[1], radix: 8),
      special: special & 4 != 0,
      executableSpecial: 's',
      nonExecutableSpecial: 'S',
    ),
    _symbolicPermissionTriplet(
      int.parse(normalized[2], radix: 8),
      special: special & 2 != 0,
      executableSpecial: 's',
      nonExecutableSpecial: 'S',
    ),
    _symbolicPermissionTriplet(
      int.parse(normalized[3], radix: 8),
      special: special & 1 != 0,
      executableSpecial: 't',
      nonExecutableSpecial: 'T',
    ),
  ].join();
}

String _symbolicPermissionTriplet(
  int digit, {
  required bool special,
  required String executableSpecial,
  required String nonExecutableSpecial,
}) {
  final read = digit & 4 != 0 ? 'r' : '-';
  final write = digit & 2 != 0 ? 'w' : '-';
  final executable = digit & 1 != 0;
  final execute = special
      ? (executable ? executableSpecial : nonExecutableSpecial)
      : (executable ? 'x' : '-');
  return '$read$write$execute';
}

String? _octalFromSymbolicPermissions(String value) {
  final symbolic = value.length == 10 && _looksLikeFileType(value[0])
      ? value.substring(1)
      : value;
  if (symbolic.length != 9) {
    return null;
  }
  final user = _octalDigitFromSymbolicTriplet(
    symbolic.substring(0, 3),
    specialExecutable: 's',
    specialNonExecutable: 'S',
  );
  final group = _octalDigitFromSymbolicTriplet(
    symbolic.substring(3, 6),
    specialExecutable: 's',
    specialNonExecutable: 'S',
  );
  final other = _octalDigitFromSymbolicTriplet(
    symbolic.substring(6, 9),
    specialExecutable: 't',
    specialNonExecutable: 'T',
  );
  if (user == null || group == null || other == null) {
    return null;
  }
  final special =
      (user.special ? 4 : 0) +
      (group.special ? 2 : 0) +
      (other.special ? 1 : 0);
  return '$special${user.digit}${group.digit}${other.digit}';
}

bool _looksLikeFileType(String value) {
  return const {'-', 'd', 'l', 'c', 'b', 'p', 's', '?'}.contains(value);
}

({int digit, bool special})? _octalDigitFromSymbolicTriplet(
  String triplet, {
  required String specialExecutable,
  required String specialNonExecutable,
}) {
  final read = switch (triplet[0]) {
    'r' => 4,
    '-' => 0,
    _ => null,
  };
  final write = switch (triplet[1]) {
    'w' => 2,
    '-' => 0,
    _ => null,
  };
  if (read == null || write == null) {
    return null;
  }

  final execute = switch (triplet[2]) {
    'x' => (digit: 1, special: false),
    '-' => (digit: 0, special: false),
    String value when value == specialExecutable => (digit: 1, special: true),
    String value when value == specialNonExecutable => (
      digit: 0,
      special: true,
    ),
    _ => null,
  };
  if (execute == null) {
    return null;
  }
  return (digit: read + write + execute.digit, special: execute.special);
}
