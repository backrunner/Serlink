import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/application/agent_config_installer.dart';
import 'package:serlink/features/mcp/application/agent_skill_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late AgentConfigInstaller configs;
  late AgentSkillInstaller installer;
  late String content;
  const original =
      '---\nname: serlink-mcp\ndescription: Use Serlink\n---\nv1\n';

  AgentConfigTarget target(String id) =>
      configs.knownTargets.singleWhere((t) => t.id == id);
  File skill(String id) => File(AgentSkillInstaller.skillPath(target(id)));
  void detect(String id) =>
      Directory(target(id).markerDirectory).createSync(recursive: true);

  setUp(() {
    home = Directory.systemTemp.createTempSync('serlink-global-skills-');
    addTearDown(() => home.deleteSync(recursive: true));
    configs = AgentConfigInstaller(homeDirectory: home.path);
    content = original;
    installer = AgentSkillInstaller(
      configInstaller: configs,
      loadContent: () async => content,
    );
  });

  test('installs bundled skill globally for detected agents without changing MCP config', () async {
    detect('claude-code');
    detect('codex');
    final config = File(target('claude-code').configPath)
      ..writeAsStringSync('{"theme":"dark"}');
    final bundled = AgentSkillInstaller(
      configInstaller: configs,
      loadContent: () =>
          rootBundle.loadString('assets/agent_skills/serlink-mcp/SKILL.md'),
    );
    final results = await bundled.refresh(synchronize: true);
    expect(results.map((r) => r.target.id), ['claude-code', 'codex']);
    expect(
      results.every((r) => r.status == AgentSkillStatus.installed),
      isTrue,
    );
    expect(
      skill('claude-code').readAsStringSync(),
      contains('serlink_sftp_upload'),
    );
    expect(
      skill('codex').readAsStringSync(),
      skill('claude-code').readAsStringSync(),
    );
    expect(
      p.normalize(skill('codex').path),
      p.join(home.path, '.agents', 'skills', 'serlink-mcp', 'SKILL.md'),
    );
    expect(config.readAsStringSync(), '{"theme":"dark"}');
    expect(Directory('${home.path}/.cursor').existsSync(), isFalse);
  });

  test(
    'inspection never creates files; no detected agents means no writes',
    () async {
      expect(await installer.refresh(synchronize: true), isEmpty);
      expect(
        (await installer.inspect(target('codex'))).status,
        AgentSkillStatus.notInstalled,
      );
      expect(home.listSync(), isEmpty);
    },
  );

  test('managed skills update with new bundled content and current skills stay untouched', () async {
    detect('codex');
    await installer.refresh(synchronize: true);
    final firstModified = skill('codex').statSync().modified;
    await installer.refresh(synchronize: true);
    expect(skill('codex').statSync().modified, firstModified);
    final extra = File('${skill('codex').parent.path}/user-notes.txt')
      ..writeAsStringSync('keep');
    content = original.replaceFirst('v1', 'v2');
    expect(
      (await installer.inspect(target('codex'))).status,
      AgentSkillStatus.outdated,
    );
    expect(
      (await installer.refresh(synchronize: true)).single.status,
      AgentSkillStatus.installed,
    );
    expect(skill('codex').readAsStringSync(), content);
    expect(extra.readAsStringSync(), 'keep');
    expect(
      (await installer.inspect(target('codex'))).status,
      AgentSkillStatus.installed,
    );
  });

  for (final managed in [false, true]) {
    test(
      'preserves ${managed ? 'customized managed' : 'unowned'} skills until explicit replacement',
      () async {
        detect('claude-code');
        if (managed) await installer.refresh(synchronize: true);
        skill('claude-code').parent.createSync(recursive: true);
        skill('claude-code').writeAsStringSync('my custom instructions');
        expect(
          (await installer.refresh(synchronize: true)).single.status,
          AgentSkillStatus.conflict,
        );
        expect(
          skill('claude-code').readAsStringSync(),
          'my custom instructions',
        );
        await installer.install(target('claude-code'), replaceExisting: true);
        expect(skill('claude-code').readAsStringSync(), content);
        final backups = skill('claude-code').parent
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('SKILL.md.serlink-backup-'))
            .toList();
        expect(backups, hasLength(1));
        expect(backups.single.readAsStringSync(), 'my custom instructions');
        skill('claude-code').writeAsStringSync('another customization');
        await installer.install(target('claude-code'), replaceExisting: true);
        expect(
          skill('claude-code').parent
              .listSync()
              .where((f) => f.path.contains('SKILL.md.serlink-backup-')),
          hasLength(2),
        );
      },
    );
  }

  test(
    'a malformed receipt never authorizes overwriting a user edit',
    () async {
      detect('codex');
      await installer.refresh(synchronize: true);
      File('${skill('codex').parent.path}/.serlink-managed.json')
          .writeAsStringSync('{broken');
      content = 'new version';
      expect(
        (await installer.refresh(synchronize: true)).single.status,
        AgentSkillStatus.conflict,
      );
      expect(skill('codex').readAsStringSync(), original);
    },
  );

  for (final linked in ['directory', 'skill', 'receipt']) {
    test(
      'never follows a symlink at the $linked, including explicit replacement',
      () async {
        detect('codex');
        final outside = Directory('${home.path}/outside')..createSync();
        final outsideFile = File('${outside.path}/instructions')
          ..writeAsStringSync('do not change');
        final directory = skill('codex').parent;
        if (linked == 'directory') {
          directory.parent.createSync(recursive: true);
          Link(directory.path).createSync(outside.path);
        } else {
          directory.createSync(recursive: true);
          if (linked == 'skill') {
            Link(skill('codex').path).createSync(outsideFile.path);
          } else {
            skill('codex').writeAsStringSync('custom');
            Link('${directory.path}/.serlink-managed.json')
                .createSync(outsideFile.path);
          }
        }
        expect(
          (await installer.refresh(synchronize: true)).single.status,
          AgentSkillStatus.conflict,
        );
        await expectLater(
          installer.install(target('codex'), replaceExisting: true),
          throwsA(isA<FileSystemException>()),
        );
        expect(outsideFile.readAsStringSync(), 'do not change');
        expect(File('${outside.path}/SKILL.md').existsSync(), isFalse);
      },
      skip: Platform.isWindows,
    );
  }

  test(
    'one inaccessible target does not stop the remaining installations',
    () async {
      detect('claude-code');
      detect('codex');
      File('${target('claude-code').markerDirectory}/skills')
          .writeAsStringSync('not a directory');
      final results = await installer.refresh(synchronize: true);
      expect(results.first.status, AgentSkillStatus.unavailable);
      expect(results.last.status, AgentSkillStatus.installed);
      expect(skill('codex').existsSync(), isTrue);
    },
  );

  test('serializes concurrent installs and detects new agents on subsequent starts', () async {
    detect('claude-code');
    final results = await Future.wait([
      installer.refresh(synchronize: true),
      installer.refresh(synchronize: true),
    ]);
    expect(
      results.every((r) => r.single.status == AgentSkillStatus.installed),
      isTrue,
    );
    detect('opencode');
    expect(
      (await installer.refresh(synchronize: true)).map((r) => r.target.id),
      ['claude-code', 'opencode'],
    );
    final receipt = jsonDecode(
      File('${skill('claude-code').parent.path}/.serlink-managed.json')
          .readAsStringSync(),
    ) as Map;
    expect(receipt['sha256'], hasLength(64));
  });

  test(
    'stopping startup synchronization prevents subsequent target writes',
    () async {
      detect('claude-code');
      detect('codex');
      var keepRunning = true;
      final stopping = AgentSkillInstaller(
        configInstaller: configs,
        loadContent: () async {
          keepRunning = false;
          return content;
        },
      );
      final results = await stopping.refresh(
        synchronize: true,
        shouldContinue: () => keepRunning,
      );
      expect(results, hasLength(1));
      expect(skill('codex').existsSync(), isFalse);
    },
  );
}
