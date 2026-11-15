import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/domain/command_approval_scope.dart';

void main() {
  test('scope matches argv boundaries and one subcommand only', () {
    final scope = CommandApprovalScope.fromCommand('git status --short')!;
    expect(scope.label, 'git status …');
    expect(scope.matches('git status --porcelain=v1'), isTrue);
    expect(scope.matches('git "status" --short'), isTrue);
    for (final command in [
      'git status-evil',
      'git reset --hard',
      'git status; rm file',
      'git status && rm file',
      'git status | sh',
      r'git status $(cleanup)',
      r'git status "$ARGS"',
      'git status > file',
    ]) {
      expect(scope.matches(command), isFalse, reason: command);
    }
  });
  test('repository and executable paths are part of the scope', () {
    final scope = CommandApprovalScope.fromCommand('git -C /srv/app status')!;
    expect(scope.matches('git -C /srv/app status -s'), isTrue);
    expect(scope.matches('git -C /srv/other status'), isFalse);
    expect(scope.matches('/tmp/git -C /srv/app status'), isFalse);
  });
  test('scripts and unknown programs get an exact argv scope', () {
    final scope = CommandApprovalScope.fromCommand(
      'custom-tool inspect "one file"',
    )!;
    expect(scope.label, "custom-tool inspect 'one file'");
    expect(scope.matches("custom-tool inspect 'one file'"), isTrue);
    expect(scope.matches('custom-tool inspect other-file'), isFalse);
    final npm = CommandApprovalScope.fromCommand('npm run test -- --watch')!;
    expect(npm.label, 'npm run test …');
    expect(npm.matches('npm run deploy'), isFalse);
  });
  for (final command in [
    r'ls "$HOME"',
    'ls; pwd',
    'ls | head',
    'sudo ls',
    'env PAGER=cleanup git status',
    r'$COMMAND arg',
    'ls > output',
    'ls &',
    'ls # comment',
    'git status "unterminated',
  ]) {
    test('no prefix grant for ambiguous input $command', () {
      expect(CommandApprovalScope.fromCommand(command), isNull);
    });
  }
  test('quoted control operators stay arguments, not separate commands', () {
    expect(literalShellCommands("echo 'rm; mkfs'"), [
      ['echo', 'rm; mkfs'],
    ]);
    expect(literalShellCommands(r'r\m file'), [
      ['rm', 'file'],
    ]);
    expect(literalShellCommands('r\\\nm file'), [
      ['rm', 'file'],
    ]);
    expect(literalShellCommands('git status && pwd'), [
      ['git', 'status'],
      ['pwd'],
    ]);
  });
}
