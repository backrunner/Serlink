import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'agent_config_installer.dart';

enum AgentSkillStatus {
  notInstalled,
  installed,
  outdated,
  conflict,
  unavailable,
}

class AgentSkillInstallation {
  const AgentSkillInstallation({
    required this.target,
    required this.status,
    this.error,
  });

  final AgentConfigTarget target;
  final AgentSkillStatus status;
  final String? error;
  String get path => AgentSkillInstaller.skillPath(target);
}

/// Owns only serlink-mcp/SKILL.md and its receipt in each agent's global root.
/// User edits and unowned skills are left for an explicit replacement action.
class AgentSkillInstaller {
  AgentSkillInstaller({
    required this.configInstaller,
    required Future<String> Function() loadContent,
    // Named parameters cannot initialize private fields directly.
    // ignore: prefer_initializing_formals
  }) : _loadContent = loadContent;

  final AgentConfigInstaller configInstaller;
  final Future<String> Function() _loadContent;
  Future<void> _queue = Future<void>.value();

  static String skillPath(AgentConfigTarget target) =>
      p.join(target.globalSkillsDirectory, 'serlink-mcp', 'SKILL.md');

  static String _receiptPath(AgentConfigTarget target) => p.join(
    target.globalSkillsDirectory,
    'serlink-mcp',
    '.serlink-managed.json',
  );

  Future<String> _digest(String contents) async =>
      (await Sha256().hash(utf8.encode(contents))).bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();

  Future<AgentSkillInstallation> inspect(AgentConfigTarget target) async {
    try {
      return await _inspect(target, await _loadContent());
    } on Object catch (error) {
      return AgentSkillInstallation(
        target: target,
        status: AgentSkillStatus.unavailable,
        error: '$error',
      );
    }
  }

  Future<AgentSkillInstallation> _inspect(
    AgentConfigTarget target,
    String contents,
  ) async {
    final file = File(skillPath(target));
    final directoryType = await FileSystemEntity.type(
      file.parent.path,
      followLinks: false,
    );
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (directoryType == FileSystemEntityType.link ||
        (directoryType != FileSystemEntityType.notFound &&
            directoryType != FileSystemEntityType.directory) ||
        (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.file)) {
      return AgentSkillInstallation(
        target: target,
        status: AgentSkillStatus.conflict,
      );
    }
    if (type == FileSystemEntityType.notFound) {
      return AgentSkillInstallation(
        target: target,
        status: AgentSkillStatus.notInstalled,
      );
    }
    final previous = await file.readAsString();
    if (previous == contents) {
      return AgentSkillInstallation(
        target: target,
        status: AgentSkillStatus.installed,
      );
    }
    final receipt = File(_receiptPath(target));
    if (await FileSystemEntity.type(receipt.path, followLinks: false) ==
        FileSystemEntityType.file) {
      try {
        final decoded = jsonDecode(await receipt.readAsString());
        if (decoded is Map &&
            decoded['managedBy'] == 'serlink' &&
            decoded['sha256'] == await _digest(previous)) {
          return AgentSkillInstallation(
            target: target,
            status: AgentSkillStatus.outdated,
          );
        }
      } on FormatException {
        // An unreadable receipt never proves ownership of a user's skill.
      }
    }
    return AgentSkillInstallation(
      target: target,
      status: AgentSkillStatus.conflict,
    );
  }

  Future<AgentSkillInstallation> install(
    AgentConfigTarget target, {
    bool replaceExisting = false,
  }) {
    final result = _queue.then((_) async {
      final contents = await _loadContent();
      return _install(target, contents, replaceExisting: replaceExisting);
    });
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<AgentSkillInstallation> _install(
    AgentConfigTarget target,
    String contents, {
    bool replaceExisting = false,
  }) async {
    final current = await _inspect(target, contents);
    if (current.status == AgentSkillStatus.installed ||
        (current.status == AgentSkillStatus.conflict && !replaceExisting)) {
      return current;
    }
    final file = File(skillPath(target));
    final receipt = File(_receiptPath(target));
    // Never follow a skill-level link or replace special files, even manually.
    for (final path in [file.parent.path, file.path, receipt.path]) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      final expected = path == file.parent.path
          ? FileSystemEntityType.directory
          : FileSystemEntityType.file;
      if (type != FileSystemEntityType.notFound && type != expected) {
        throw FileSystemException(
          'Skill path is not a regular file or directory',
          path,
        );
      }
    }
    await file.parent.create(recursive: true);
    final staging = await file.parent.createTemp('.serlink-');
    try {
      if (current.status == AgentSkillStatus.conflict && await file.exists()) {
        // Back up every explicit replacement, rather than overwriting an old backup.
        final backup = File(
          '${file.path}.serlink-backup-${p.basename(staging.path)}',
        );
        await file.copy(backup.path);
      }
      final next = File(p.join(staging.path, 'content'));
      final nextReceipt = File(p.join(staging.path, 'receipt'));
      await next.writeAsString(contents, flush: true);
      await nextReceipt.writeAsString(
        jsonEncode({'managedBy': 'serlink', 'sha256': await _digest(contents)}),
        flush: true,
      );
      final latest = await _inspect(target, contents);
      if (latest.status == AgentSkillStatus.conflict && !replaceExisting) {
        return latest;
      }
      await next.rename(file.path);
      await nextReceipt.rename(receipt.path);
    } finally {
      await staging.delete(recursive: true);
    }
    return AgentSkillInstallation(
      target: target,
      status: AgentSkillStatus.installed,
    );
  }

  /// Re-detect on every call so newly installed agents appear on the next start.
  /// A failed target does not stop the remaining agents or the MCP listener.
  Future<List<AgentSkillInstallation>> refresh({
    bool synchronize = false,
    bool Function()? shouldContinue,
  }) async {
    final targets = configInstaller.detectInstalledAgents();
    final results = <AgentSkillInstallation>[];
    for (final target in targets) {
      if (shouldContinue?.call() == false) break;
      try {
        results.add(
          synchronize ? await install(target) : await inspect(target),
        );
      } on Object catch (error) {
        results.add(
          AgentSkillInstallation(
            target: target,
            status: AgentSkillStatus.unavailable,
            error: '$error',
          ),
        );
      }
    }
    return results;
  }
}
