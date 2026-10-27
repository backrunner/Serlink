import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../sftp/domain/sftp_entry.dart';

/// An in-memory remote filesystem, shared by the demo shell and SFTP.
/// Paths here never resolve against the device filesystem.
class DemoFileSystem {
  DemoFileSystem() {
    for (final path in [
      '/',
      '/home',
      home,
      '$home/documents',
      '$home/uploads',
      '$home/logs',
    ]) {
      directories.add(path);
    }
    write(
      '$home/README.txt',
      utf8.encode(
        'Welcome to the Serlink offline demo.\n'
        'These files and terminal commands are simulated in memory.\n'
        'Try help, ls, cd documents, cat notes.txt, mkdir, touch, mv and rm.\n'
        'SFTP changes appear in the terminal and terminal changes appear in SFTP.\n'
        'Use the separate review server from App Review notes for real SSH/SFTP.\n',
      ),
    );
    write(
      '$home/documents/notes.txt',
      utf8.encode(
        'Serlink review workspace\n\n'
        '1. Preview and edit this file using SFTP.\n'
        '2. Upload a disposable file to uploads.\n'
        '3. Download README.txt using the native save panel.\n',
      ),
    );
    write(
      '$home/documents/example.json',
      utf8.encode(
        '{\n  "service": "serlink-demo",\n  "status": "ready",\n  "region": "Singapore"\n}\n',
      ),
    );
    write(
      '$home/logs/application.log',
      utf8.encode(
        '2026-10-19T00:00:00Z INFO Demo workspace ready\n'
        '2026-10-19T00:00:01Z INFO SFTP preview available\n'
        '2026-10-19T00:00:02Z INFO No external connection was made\n',
      ),
    );
  }

  static const home = '/home/reviewer';
  final Set<String> directories = {};
  final Map<String, List<int>> files = {};
  final Map<String, SftpPermissions> modes = {};
  final Map<String, DateTime> modified = {};
  static const maxBytes = 16 * 1024 * 1024;

  String resolve(String path, [String cwd = home]) => p.posix.normalize(
    p.posix.isAbsolute(path) ? path : p.posix.join(cwd, path),
  );

  bool exists(String path) =>
      directories.contains(path) || files.containsKey(path);

  List<int> read(String path) {
    final bytes = files[path];
    if (bytes == null) throw FileSystemException('No such file', path);
    return List.of(bytes);
  }

  void write(String path, List<int> bytes) {
    if (!directories.contains(p.posix.dirname(path)) ||
        directories.contains(path)) {
      throw FileSystemException('Invalid file destination', path);
    }
    final total = files.entries
        .where((e) => e.key != path)
        .fold<int>(0, (n, e) => n + e.value.length);
    if (bytes.length + total > maxBytes) {
      throw const FileSystemException('Demo storage limit is 16 MiB');
    }
    files[path] = List.of(bytes);
    modified[path] = DateTime.now();
  }

  void mkdir(String path) {
    if (exists(path)) throw FileSystemException('File already exists', path);
    if (!directories.contains(p.posix.dirname(path))) {
      throw FileSystemException('No such directory', path);
    }
    directories.add(path);
    modified[path] = DateTime.now();
  }

  List<SftpEntry> list(String path) {
    if (!directories.contains(path)) {
      throw FileSystemException('No such directory', path);
    }
    final paths =
        {...directories, ...files.keys}
            .where((item) => item != '/' && p.posix.dirname(item) == path)
            .toList()
          ..sort();
    return [
      for (final item in paths)
        SftpEntry(
          name: p.posix.basename(item),
          path: item,
          type: directories.contains(item)
              ? SftpEntryType.directory
              : SftpEntryType.file,
          size: files[item]?.length ?? 0,
          permissions:
              modes[item] ??
              SftpPermissions(directories.contains(item) ? '0755' : '0644'),
          owner: 'reviewer',
          group: 'reviewer',
          modifiedAt: modified[item] ?? DateTime.utc(2026, 10, 19),
          isHidden: p.posix.basename(item).startsWith('.'),
        ),
    ];
  }

  void remove(String path, {bool recursive = false}) {
    if (path == '/' || path == '/home' || path == home) {
      throw const FileSystemException('Demo root is protected');
    }
    if (!exists(path)) throw FileSystemException('No such file', path);
    if (directories.contains(path) && list(path).isNotEmpty && !recursive) {
      throw FileSystemException('Directory is not empty', path);
    }
    final removed = {
      ...directories,
      ...files.keys,
    }.where((item) => item == path || item.startsWith('$path/')).toList();
    for (final item in removed) {
      directories.remove(item);
      files.remove(item);
      modes.remove(item);
      modified.remove(item);
    }
  }

  void rename(String source, String target) {
    if (!exists(source) || !directories.contains(p.posix.dirname(target))) {
      throw const FileSystemException('No such file or directory');
    }
    if (source == '/' ||
        source == '/home' ||
        source == home ||
        target.startsWith('$source/')) {
      throw const FileSystemException('Invalid move');
    }
    if (exists(target)) {
      throw FileSystemException('Destination already exists', target);
    }
    final moved = {
      ...directories,
      ...files.keys,
    }.where((item) => item == source || item.startsWith('$source/')).toList();
    for (final item in moved) {
      final next = '$target${item.substring(source.length)}';
      if (directories.remove(item)) directories.add(next);
      final bytes = files.remove(item);
      if (bytes != null) files[next] = bytes;
      final mode = modes.remove(item);
      if (mode != null) modes[next] = mode;
      modified.remove(item);
      modified[next] = DateTime.now();
    }
  }
}
