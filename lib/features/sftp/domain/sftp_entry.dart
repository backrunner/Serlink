enum SftpEntryType { file, directory, symlink, unknown }

class SftpPermissions {
  const SftpPermissions(this.octal);

  final String octal;
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
