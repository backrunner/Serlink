import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/data/command_output_store.dart';

void main() {
  test(
    'all pages preserve large Unicode output without plaintext on disk',
    () async {
      final store = await CommandOutputStore.create();
      final directory = store.directory;
      final expected = 'sensitive-command-output-中文🙂\n' * 6000;
      await store.append(expected);
      final all = StringBuffer();
      var cursor = 0;
      while (cursor < store.length) {
        final page = await store.read(cursor: cursor, maxChars: 4097);
        expect(page.text.contains('\ufffd'), isFalse);
        expect(page.cursor, cursor);
        all.write(page.text);
        expect(page.nextCursor, greaterThan(cursor));
        cursor = page.nextCursor;
        expect(page.hasMore, cursor < expected.length);
      }
      expect(all.toString(), expected);
      final bytes = await File('${directory.path}/output.enc').readAsBytes();
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('sensitive-command-output')),
      );
      await store.dispose();
      expect(directory.existsSync(), isFalse);
    },
  );

  test(
    'capture limits are explicit and never create an invisible gap',
    () async {
      final store = await CommandOutputStore.create(maxBytes: 65536);
      addTearDown(store.dispose);
      await store.append('a' * 32768);
      await store.append('b' * 32768);
      await store.append('overflow');
      await store.append('tail');
      expect(store.truncated, isTrue);
      final page = await store.read(cursor: 0);
      expect(page.text, '${'a' * 32768}${'b' * 32768}');
      expect(page.hasMore, isFalse);
      await expectLater(
        store.read(cursor: store.length + 1),
        throwsFormatException,
      );
    },
  );
}
