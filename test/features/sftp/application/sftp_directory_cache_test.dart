import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sftp/application/sftp_directory_cache.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';

void main() {
  const entry = SftpEntry(
    name: 'file',
    path: '/file',
    type: SftpEntryType.file,
  );

  test('evicts the least recently read directory and expires entries', () {
    var now = DateTime.utc(2026);
    final cache = SftpDirectoryCache(maxDirectories: 2, now: () => now);
    cache.store('/a', [entry]);
    cache.store('/b', [entry]);
    expect(cache.read('/a'), [entry]);
    cache.store('/c', [entry]);
    expect(cache.read('/b'), isNull);
    expect(cache.read('/a'), [entry]);
    now = now.add(const Duration(seconds: 5));
    expect(cache.read('/a'), isNull);
    expect(cache.read('/c'), isNull);
  });

  test('bounds entry count, replaces values, and invalidates paths', () {
    final cache = SftpDirectoryCache(maxEntries: 3);
    cache.store('/a', [entry, entry]);
    cache.store('/b', [entry, entry]);
    expect(cache.read('/a'), isNull);
    cache.store('/huge', List.filled(4, entry));
    expect(cache.read('/huge'), isNull);
    cache.store('/b', [entry]);
    cache.store('/c', [entry, entry]);
    expect(cache.read('/b'), [entry]);
    cache.invalidate('/b');
    expect(cache.read('/b'), isNull);
    cache.invalidate();
    expect(cache.read('/c'), isNull);
  });
}
