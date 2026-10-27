import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/demo/demo_file_system.dart';
import 'package:serlink/features/demo/demo_shell.dart';
import 'package:serlink/features/demo/demo_ssh_service.dart';
import 'package:serlink/features/demo/demo_workspace.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'shell and SFTP share mutations and remote paths remain virtual',
    () async {
      final fs = DemoFileSystem();
      final shell = DemoShell(fs);
      final sftp = DemoSftpConnection(fs);
      addTearDown(shell.close);
      addTearDown(sftp.close);
      shell.run('mkdir work');
      shell.run('echo "hello reviewer" > work/message.txt');
      expect(
        (await sftp.readTextPreview('${DemoFileSystem.home}/work/message.txt'))
            .text,
        'hello reviewer\n',
      );
      await sftp.rename(
        '${DemoFileSystem.home}/work',
        '${DemoFileSystem.home}/renamed',
      );
      expect(shell.run('cat renamed/message.txt'), 'hello reviewer');
      await sftp.writeTextFile(
        '${DemoFileSystem.home}/renamed/message.txt',
        'SFTP edit\n',
      );
      expect(shell.run('cat renamed/message.txt'), 'SFTP edit');
      expect(shell.run('cd ../../../../'), '');
      expect(shell.run('pwd'), '/');
      expect(
        () => shell.run('cat /etc/passwd'),
        throwsA(isA<FileSystemException>()),
      );
      expect(shell.run('curl https://example.com'), contains('unavailable'));
      expect(
        () => fs.rename(DemoFileSystem.home, '/moved'),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        () =>
            fs.write('/oversize', List.filled(DemoFileSystem.maxBytes + 1, 0)),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'UTF-8 chunked input, history and CRLF produce one command each',
    () async {
      final shell = DemoShell(DemoFileSystem());
      final output = StringBuffer();
      final subscription = shell.stdout.listen(
        (bytes) => output.write(utf8.decode(bytes)),
      );
      addTearDown(subscription.cancel);
      addTearDown(shell.close);
      final bytes = utf8.encode('echo 你好\r\n');
      for (final byte in bytes) {
        await shell.write([byte]);
      }
      await Future<void>.delayed(Duration.zero);
      expect(output.toString(), contains('你好\r\nreviewer@offline-demo:'));
      final before = output.length;
      await shell.write(utf8.encode('\x1b[A\r'));
      await Future<void>.delayed(Duration.zero);
      expect(output.toString().substring(before), contains('你好\r\n'));
    },
  );

  test(
    'SFTP transfers preserve real selected file bytes and nested directories',
    () async {
      final dir = await Directory.systemTemp.createTemp('serlink-demo-test-');
      addTearDown(() => dir.delete(recursive: true));
      final fs = DemoFileSystem();
      final sftp = DemoSftpConnection(fs);
      addTearDown(sftp.close);
      final source = File('${dir.path}/input.bin');
      await source.writeAsBytes([0, 127, 255, 42]);
      final upload = await sftp
          .upload(
            taskId: TransferTaskId('upload'),
            itemKind: TransferItemKind.file,
            localPath: source.path,
            remotePath: '${DemoFileSystem.home}/uploads/input.bin',
          )
          .toList();
      expect(upload.last.state, TransferState.completed);
      expect(upload.last.transferredBytes, 4);
      final output = File('${dir.path}/output.bin');
      await sftp
          .download(
            taskId: TransferTaskId('download'),
            itemKind: TransferItemKind.file,
            remotePath: '${DemoFileSystem.home}/uploads/input.bin',
            localPath: output.path,
          )
          .drain<void>();
      expect(await output.readAsBytes(), [0, 127, 255, 42]);
      await sftp
          .download(
            taskId: TransferTaskId('directory'),
            itemKind: TransferItemKind.directory,
            remotePath: '${DemoFileSystem.home}/documents',
            localPath: '${dir.path}/docs',
          )
          .drain<void>();
      expect(
        await File('${dir.path}/docs/notes.txt').readAsString(),
        contains('review workspace'),
      );
      await sftp.close();
      expect(sftp.list('/'), throwsA(isA<FileSystemException>()));
    },
  );

  test(
    'demo workspace is seeded, independent and cannot start cloud sync',
    () async {
      const capabilities = PlatformCapabilities(
        operatingSystem: 'macos',
        targetPlatform: TargetPlatform.macOS,
        distribution: SerlinkDistribution.appStore,
      );
      final first = await DemoWorkspace.create(capabilities: capabilities);
      addTearDown(first.dispose);
      final second = await DemoWorkspace.create(capabilities: capabilities);
      addTearDown(second.dispose);
      final hosts = await first.container.read(hostRepositoryProvider).list();
      expect(hosts, hasLength(3));
      expect(
        await first.container.read(identityRepositoryProvider).list(),
        hasLength(1),
      );
      expect(
        await first.container.read(snippetRepositoryProvider).list(),
        hasLength(4),
      );
      expect(
        await first.container.read(syncDeviceRepositoryProvider).list(),
        hasLength(2),
      );
      final bridge = first.container.read(agentSessionBridgeProvider);
      final ordinary = await bridge.describeHosts();
      expect(ordinary.first['hostname'], endsWith('.invalid'));
      expect(ordinary.first['username'], 'reviewer');
      expect(ordinary.first.containsKey('identityIds'), isFalse);
      expect(ordinary.first.containsKey('secretRecordId'), isFalse);
      await first.container.read(mcpHostVisibilityProvider).saveStrict(true);
      final strict = await bridge.describeHosts();
      expect(strict.first.keys, unorderedEquals(['id', 'displayName']));
      await first.container.read(mcpHostVisibilityProvider).saveStrict(false);
      expect(
        (await bridge.describeHosts()).first['hostname'],
        endsWith('.invalid'),
      );
      await first.container.read(hostRepositoryProvider).delete(hosts.first.id);
      expect(
        await second.container.read(hostRepositoryProvider).list(),
        hasLength(3),
      );
      final demoCapabilities = first.container.read(
        platformCapabilitiesProvider,
      );
      expect(demoCapabilities.isDemo, isTrue);
      expect(demoCapabilities.mcpServer, isFalse);
      expect(demoCapabilities.cloudKitSync, isFalse);
      expect(demoCapabilities.sshConfigImport, isFalse);
      expect(
        await first.container
            .read(syncSettingsServiceProvider)
            .activeSyncProviders(),
        isEmpty,
      );
      expect(
        first.container.read(syncSettingsServiceProvider).buildWebDavProvider(),
        throwsA(isA<Exception>()),
      );
      final temporary = first.temporary;
      await first.dispose();
      expect(await temporary.exists(), isFalse);
    },
  );
}
