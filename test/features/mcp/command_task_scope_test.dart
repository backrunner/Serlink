import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/domain/command_approval_scope.dart';
import 'package:serlink/features/mcp/domain/command_task_scope.dart';

void main() {
  final scope = CommandTaskScope.fromCommand('pwd', '/srv/app')!;
  for (final command in [
    'pwd',
    'ls -la',
    "rg -n 'rm|mkfs' README.md",
    "sed -n '1,120p' lib/main.dart",
    "find lib -name '*.dart'",
    'git -C /srv/app status --short',
    'cp src/a.txt out/a.txt',
    'cp -n src/a.txt out/a.txt',
    'mkdir -p out/new',
    'touch out/new.txt',
    r"printf 'hello\n' | tee out/report.txt",
    "printf 'rm -rf /' > out/note.txt",
    "printf 'update' >> /srv/app/out/note.txt",
    'cat src/a.txt && printf x > out/x.txt',
    "echo '> /etc/passwd'",
  ]) {
    test('project permission covers $command', () {
      expect(scope.matches(command), isTrue);
    });
  }
  for (final command in [
    'rm out/a.txt',
    'mv src/a.txt out/a.txt',
    'cp -R src out',
    'cp -f src/a.txt out/a.txt',
    'cp /etc/passwd out/a.txt',
    'cp src/a.txt /srv/app-other/a.txt',
    'cat ../other/a.txt',
    'cat /etc/passwd',
    'tee /srv/app/../other/a.txt',
    'touch .env',
    'touch .git/config',
    'cp .ssh/id_rsa out/key',
    'git reset --hard',
    'git checkout -b feature/task',
    'git restore --staged file.txt',
    'git -C /srv/other status',
    'git diff --no-index a /etc/passwd',
    'rg --pre=cleanup README.md',
    'rg -f/etc/passwd README.md',
    'ls --ignore=/etc/passwd',
    'find . -exec cleanup {} +',
    "sed -n '1e cleanup' file.txt",
    'sudo cp src/a.txt out/a.txt',
    'env cp src/a.txt out/a.txt',
    'cd /tmp && touch a.txt',
    'python3 -c "print(1)"',
    './touch out/a.txt',
    '/tmp/cat out/a.txt',
    r'cat $FILE',
    r'printf "$(cleanup)" > out/a.txt',
    'printf x > ~/.bashrc',
    'printf x > /srv/app/.env',
    'printf x > /dev/sda',
    'printf x > /srv/other/a.txt',
    'printf x 2> out/a.txt',
    'cat < out/a.txt',
    'printf x >',
    'printf x > > out/a.txt',
    'printf x > out/a.txt; rm x',
  ]) {
    test('project permission cannot cover $command', () {
      expect(scope.matches(command), isFalse);
    });
  }
  test('task requires an explicit canonical non-system directory', () {
    for (final directory in [
      null,
      '',
      '/',
      '/srv',
      '.',
      'relative/project',
      '/srv/app/',
      '/srv/../app',
      '/srv/.private',
      '/etc/app',
      '/usr/local',
    ]) {
      expect(
        CommandTaskScope.fromCommand('pwd', directory),
        isNull,
        reason: '$directory',
      );
    }
  });
  test('redirection operators and quoted operator arguments stay distinct', () {
    final steps = literalShellSteps("printf '>' > 'out/one file'")!;
    expect(steps.single.words, ['printf', '>']);
    expect(steps.single.outputPaths, ['out/one file']);
    expect(literalShellCommands("printf '>' > 'out/one file'"), isNull);
    expect(literalShellCommands("echo '>'"), [
      ['echo', '>'],
    ]);
  });
}
