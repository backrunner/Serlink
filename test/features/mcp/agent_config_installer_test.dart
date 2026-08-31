import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/application/agent_config_installer.dart';

void main() {
  late Directory home;
  late AgentConfigInstaller installer;

  const helperPath = '/Applications/Serlink.app/Contents/MacOS/serlink-mcp';

  AgentConfigTarget target(String id) {
    return installer.knownTargets.singleWhere((target) => target.id == id);
  }

  setUp(() {
    home = Directory.systemTemp.createTempSync('serlink-agent-config-test');
    addTearDown(() => home.deleteSync(recursive: true));
    installer = AgentConfigInstaller(homeDirectory: home.path);
  });

  test('detects agents by config file or parent directory', () {
    expect(installer.detectInstalledAgents(), isEmpty);

    Directory('${home.path}/.cursor').createSync();
    File('${home.path}/.claude.json').writeAsStringSync('{}');

    final detected = installer.detectInstalledAgents();
    expect(detected.map((target) => target.id), [
      'claude-code',
      'cursor',
    ]);
  });

  test('json install merges into an existing config and keeps other keys', () async {
    final claude = target('claude-code');
    File(claude.configPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'theme': 'dark',
        'mcpServers': {
          'other': {'type': 'stdio', 'command': '/usr/local/bin/other'},
        },
      }),
    );

    await installer.install(claude, helperPath: helperPath);

    final merged =
        jsonDecode(File(claude.configPath).readAsStringSync())
            as Map<String, Object?>;
    expect(merged['theme'], 'dark');
    final servers = merged['mcpServers']! as Map<String, Object?>;
    expect((servers['other']! as Map)['command'], '/usr/local/bin/other');
    expect(servers['serlink'], {
      'type': 'stdio',
      'command': helperPath,
    });
    expect(
      installer.statusFor(claude, helperPath: helperPath),
      AgentConfigStatus.installed,
    );

    // The pre-write backup holds the original content.
    final backup = File('${claude.configPath}.serlink-backup');
    expect(backup.existsSync(), isTrue);
    expect(backup.readAsStringSync(), contains('"theme": "dark"'));
  });

  test('json install creates the file and parents when missing', () async {
    final windsurf = target('windsurf');
    await installer.install(windsurf, helperPath: helperPath);

    final written =
        jsonDecode(File(windsurf.configPath).readAsStringSync())
            as Map<String, Object?>;
    expect(written, {
      'mcpServers': {
        'serlink': {'type': 'stdio', 'command': helperPath},
      },
    });
  });

  test('json status detects outdated entries', () async {
    final cursor = target('cursor');
    Directory('${home.path}/.cursor').createSync(recursive: true);
    File(cursor.configPath).writeAsStringSync(
      jsonEncode({
        'mcpServers': {
          'serlink': {'type': 'stdio', 'command': '/old/path/serlink-mcp'},
        },
      }),
    );

    expect(
      installer.statusFor(cursor, helperPath: helperPath),
      AgentConfigStatus.outdated,
    );

    await installer.install(cursor, helperPath: helperPath);
    expect(
      installer.statusFor(cursor, helperPath: helperPath),
      AgentConfigStatus.installed,
    );
  });

  test('json install refuses malformed configs without clobbering', () async {
    final claude = target('claude-code');
    File(claude.configPath).writeAsStringSync('{not json');

    await expectLater(
      installer.install(claude, helperPath: helperPath),
      throwsA(isA<Object>()),
    );
    expect(File(claude.configPath).readAsStringSync(), '{not json');
  });

  test('kimi-code install writes a plain command entry into mcp.json', () async {
    final kimi = target('kimi-code');
    Directory('${home.path}/.kimi-code').createSync();

    await installer.install(kimi, helperPath: helperPath);

    final written =
        jsonDecode(File(kimi.configPath).readAsStringSync())
            as Map<String, Object?>;
    expect(written, {
      'mcpServers': {
        'serlink': {'command': helperPath},
      },
    });
    expect(
      installer.statusFor(kimi, helperPath: helperPath),
      AgentConfigStatus.installed,
    );
  });

  test('opencode install writes a local entry under the mcp key', () async {
    final opencode = target('opencode');
    Directory('${home.path}/.config/opencode').createSync(recursive: true);
    File(opencode.configPath).writeAsStringSync(
      jsonEncode({
        r'$schema': 'https://opencode.ai/config.json',
        'model': 'anthropic/claude-sonnet-4-5',
      }),
    );

    await installer.install(opencode, helperPath: helperPath);

    final written =
        jsonDecode(File(opencode.configPath).readAsStringSync())
            as Map<String, Object?>;
    expect(written[r'$schema'], 'https://opencode.ai/config.json');
    expect(written['model'], 'anthropic/claude-sonnet-4-5');
    expect(written['mcp'], {
      'serlink': {
        'type': 'local',
        'command': [helperPath],
        'enabled': true,
      },
    });
    expect(
      installer.statusFor(opencode, helperPath: helperPath),
      AgentConfigStatus.installed,
    );
  });

  test('toml install appends and replaces the serlink section', () async {
    final codex = target('codex');
    Directory('${home.path}/.codex').createSync();
    final configFile = File(codex.configPath)
      ..writeAsStringSync('model = "gpt-5"\n');

    await installer.install(codex, helperPath: helperPath);
    var content = configFile.readAsStringSync();
    expect(content, contains('model = "gpt-5"'));
    expect(content, contains('[mcp_servers.serlink]'));
    expect(content, contains('command = "$helperPath"'));
    expect(
      installer.statusFor(codex, helperPath: helperPath),
      AgentConfigStatus.installed,
    );

    // Reinstalling with a different path replaces the stale section in place.
    const newHelper = '/opt/serlink/serlink-mcp';
    await installer.install(codex, helperPath: newHelper);
    content = configFile.readAsStringSync();
    expect('[mcp_servers.serlink]'.allMatches(content), hasLength(1));
    expect(content, contains('command = "$newHelper"'));
    expect(content, isNot(contains(helperPath)));
    expect(content, contains('model = "gpt-5"'));
    expect(
      installer.statusFor(codex, helperPath: newHelper),
      AgentConfigStatus.installed,
    );
  });
}
