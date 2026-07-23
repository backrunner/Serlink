import 'dart:convert';

import '../../../core/ids/entity_id.dart';

class SyncConflictFieldChoice {
  const SyncConflictFieldChoice({
    required this.key,
    required this.label,
    required this.localValue,
    required this.remoteValue,
  });

  final String key;
  final String label;
  final Object? localValue;
  final Object? remoteValue;

  bool get differs => !_deepEquals(localValue, remoteValue);
}

class SyncConflictFieldSet {
  const SyncConflictFieldSet({
    required this.recordType,
    required this.recordId,
    required this.localJson,
    required this.remoteJson,
    required this.fields,
    required this.supportsFieldMerge,
  });

  final String recordType;
  final VaultRecordId recordId;
  final Map<String, Object?> localJson;
  final Map<String, Object?> remoteJson;
  final List<SyncConflictFieldChoice> fields;
  final bool supportsFieldMerge;
}

class SyncFieldMergeService {
  const SyncFieldMergeService();

  SyncConflictFieldSet inspect({
    required String recordType,
    required VaultRecordId recordId,
    required Map<String, Object?> localJson,
    required Map<String, Object?> remoteJson,
  }) {
    return switch (recordType) {
      'host' => SyncConflictFieldSet(
        recordType: recordType,
        recordId: recordId,
        localJson: localJson,
        remoteJson: remoteJson,
        supportsFieldMerge: true,
        fields: _hostFields(localJson, remoteJson),
      ),
      'snippet' => SyncConflictFieldSet(
        recordType: recordType,
        recordId: recordId,
        localJson: localJson,
        remoteJson: remoteJson,
        supportsFieldMerge: true,
        fields: _snippetFields(localJson, remoteJson),
      ),
      'sync_settings' => SyncConflictFieldSet(
        recordType: recordType,
        recordId: recordId,
        localJson: localJson,
        remoteJson: remoteJson,
        supportsFieldMerge: true,
        fields: _syncSettingsFields(localJson, remoteJson),
      ),
      _ => SyncConflictFieldSet(
        recordType: recordType,
        recordId: recordId,
        localJson: localJson,
        remoteJson: remoteJson,
        supportsFieldMerge: false,
        fields: const [],
      ),
    };
  }

  Map<String, Object?> merge({
    required SyncConflictFieldSet fieldSet,
    required Map<String, bool> useRemoteByField,
  }) {
    final merged = <String, Object?>{};
    final keys = {...fieldSet.localJson.keys, ...fieldSet.remoteJson.keys};
    for (final key in keys) {
      final useRemote = useRemoteByField[key] ?? false;
      merged[key] = useRemote
          ? fieldSet.remoteJson[key]
          : fieldSet.localJson[key];
    }
    return merged;
  }

  List<SyncConflictFieldChoice> _hostFields(
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) {
    return [
      _field('displayName', 'Name', local, remote),
      _field('hostname', 'Host', local, remote),
      _field('username', 'Username', local, remote),
      _field('port', 'Port', local, remote),
      _field('authKinds', 'Auth', local, remote),
      _field('tags', 'Tags', local, remote),
      _field('trustState', 'Trust', local, remote),
      _field('identityIds', 'Identities', local, remote),
      _field('startupCommands', 'Startup', local, remote),
      _field('remoteSessionSettings', 'Remote session', local, remote),
      _field('jumpHostIds', 'Jump hosts', local, remote),
      _field('writeBackToSshConfig', 'Write to SSH config', local, remote),
      _field('groupId', 'Group', local, remote),
      _field('lastConnectedAt', 'Last connected', local, remote),
    ].where((field) => field.differs).toList();
  }

  List<SyncConflictFieldChoice> _snippetFields(
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) {
    return [
      _field('name', 'Name', local, remote),
      _field('command', 'Command', local, remote),
      _field('tags', 'Tags', local, remote),
      _field('confirmBeforeRun', 'Confirm before run', local, remote),
    ].where((field) => field.differs).toList();
  }

  List<SyncConflictFieldChoice> _syncSettingsFields(
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) {
    return [
      _field('endpoint', 'Endpoint', local, remote),
      _field('username', 'Username', local, remote),
      _field('basePath', 'Base path', local, remote),
      _field('passwordRef', 'Password ref', local, remote),
      _field('allowInsecureHttp', 'Allow HTTP', local, remote),
      _field('enabled', 'Enabled', local, remote),
    ].where((field) => field.differs).toList();
  }

  SyncConflictFieldChoice _field(
    String key,
    String label,
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) {
    return SyncConflictFieldChoice(
      key: key,
      label: label,
      localValue: local[key],
      remoteValue: remote[key],
    );
  }
}

bool _deepEquals(Object? left, Object? right) {
  return jsonEncode(left) == jsonEncode(right);
}

String describeConflictValue(Object? value) {
  return switch (value) {
    null => 'None',
    final bool v => v ? 'Yes' : 'No',
    final List<Object?> list => list.isEmpty ? 'None' : list.join(', '),
    _ => value.toString(),
  };
}
