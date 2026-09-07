import '../domain/sftp_entry.dart';

/// A short-lived LRU cache, bounded by both directories and retained entries.
class SftpDirectoryCache {
  SftpDirectoryCache({
    this.ttl = const Duration(seconds: 5),
    this.maxDirectories = 16,
    this.maxEntries = 50000,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration ttl;
  final int maxDirectories;
  final int maxEntries;
  final DateTime Function() _now;
  final _entries = <String, ({DateTime savedAt, List<SftpEntry> entries})>{};

  List<SftpEntry>? read(String path) {
    _expire();
    final cached = _entries.remove(path);
    if (cached == null) return null;
    _entries[path] = cached;
    return cached.entries;
  }

  void store(String path, List<SftpEntry> entries) {
    _expire();
    _entries.remove(path);
    if (maxDirectories <= 0 || entries.length > maxEntries) return;
    var count = _entries.values.fold<int>(
      0,
      (sum, item) => sum + item.entries.length,
    );
    while (_entries.isNotEmpty &&
        (_entries.length >= maxDirectories ||
            count + entries.length > maxEntries)) {
      count -= _entries.remove(_entries.keys.first)!.entries.length;
    }
    _entries[path] = (savedAt: _now(), entries: List.unmodifiable(entries));
  }

  void invalidate([String? path]) {
    if (path == null) {
      _entries.clear();
    } else {
      _entries.remove(path);
    }
  }

  void _expire() {
    final now = _now();
    _entries.removeWhere((_, entry) => now.difference(entry.savedAt) >= ttl);
  }
}
