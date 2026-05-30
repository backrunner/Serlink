part of '../workspace_screen.dart';

Future<void> _exportVaultBackup(BuildContext context, WidgetRef ref) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Export encrypted backup?',
    body:
        'The backup contains encrypted vault records and the vault header. Keep it private.',
    confirmLabel: 'Export',
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final bundle = await ref.read(vaultBackupServiceProvider).exportBackup();
    final location = await getSaveLocation(
      suggestedName: 'serlink-vault-backup.srlkvault',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Serlink Vault Backup', extensions: ['srlkvault']),
      ],
    );
    if (location == null) {
      return;
    }
    final file = XFile.fromData(
      Uint8List.fromList(bundle.toBytes()),
      mimeType: 'application/json',
      name: 'serlink-vault-backup.srlkvault',
    );
    await file.saveTo(location.path);
    if (context.mounted) {
      _showSnackBar(context, 'Encrypted backup exported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _backupErrorMessage(error));
    }
  }
}

Future<void> _exportHostMetadata(BuildContext context, WidgetRef ref) async {
  try {
    final hosts = await ref.read(hostRepositoryProvider).list();
    hosts.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (hosts.isEmpty) {
      _showSnackBar(context, 'No hosts are available to export.');
      return;
    }
    final selectedHostIds = await _showHostSelectionDialog(
      context,
      hosts,
      title: 'Export host metadata?',
      description:
          'Exports host names, addresses, usernames, tags, jump host links, and connection options. Credentials and private key material are excluded.',
    );
    if (selectedHostIds == null ||
        selectedHostIds.isEmpty ||
        !context.mounted) {
      return;
    }
    final bundle = await ref
        .read(hostMetadataExportServiceProvider)
        .export(selectedHostIds: selectedHostIds);
    if (!context.mounted) {
      return;
    }
    final location = await getSaveLocation(
      suggestedName: 'serlink-host-metadata.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Serlink Host Metadata', extensions: ['json']),
      ],
    );
    if (location == null) {
      return;
    }
    final file = File(location.path);
    await file.writeAsBytes(bundle.toBytes(), flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    if (context.mounted) {
      _showSnackBar(context, 'Host metadata exported.');
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Host metadata could not be exported.');
    }
  }
}

Future<void> _exportOpenSshConfig(BuildContext context, WidgetRef ref) async {
  try {
    final hosts = await ref.read(hostRepositoryProvider).list();
    hosts.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (hosts.isEmpty) {
      _showSnackBar(context, 'No hosts are available to export.');
      return;
    }
    final selectedHostIds = await _showHostSelectionDialog(
      context,
      hosts,
      title: 'Export OpenSSH config?',
      description:
          'Exports selected hosts and any required jump hosts as an OpenSSH config. Credentials and private key material are excluded.',
    );
    if (selectedHostIds == null ||
        selectedHostIds.isEmpty ||
        !context.mounted) {
      return;
    }
    final decision = await ref
        .read(securityModalServiceProvider)
        .confirmExport(
          const ExportPreview(
            title: 'Export OpenSSH config?',
            encrypted: false,
            sensitiveFields: [
              'hostnames',
              'usernames',
              'ports',
              'jump host aliases',
              'connection settings',
            ],
          ),
        );
    if (decision != ExportDecision.confirm || !context.mounted) {
      return;
    }
    final bundle = await ref
        .read(openSshConfigExportServiceProvider)
        .export(selectedHostIds: selectedHostIds);
    final location = await getSaveLocation(
      suggestedName: 'serlink-openssh-config.sshconfig',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'OpenSSH Config',
          extensions: ['sshconfig', 'config', 'txt'],
        ),
      ],
    );
    if (location == null) {
      return;
    }
    final file = File(location.path);
    await file.writeAsString(bundle.contents, flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    if (context.mounted) {
      _showSnackBar(context, 'OpenSSH config exported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _openSshConfigExportErrorMessage(error));
    }
  }
}

Future<void> _exportIdentityMetadata(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await ref
      .read(securityModalServiceProvider)
      .confirmExport(
        const ExportPreview(
          title: 'Export identity metadata?',
          encrypted: false,
          sensitiveFields: [
            'display names',
            'username hints',
            'public key fingerprints',
            'certificate principals',
          ],
        ),
      );
  if (confirmed != ExportDecision.confirm || !context.mounted) {
    return;
  }

  try {
    final bundle = await ref
        .read(identityMetadataExportServiceProvider)
        .export();
    final location = await getSaveLocation(
      suggestedName: 'serlink-identity-metadata.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Serlink Identity Metadata', extensions: ['json']),
      ],
    );
    if (location == null) {
      return;
    }
    final file = File(location.path);
    await file.writeAsBytes(bundle.toBytes(), flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    if (context.mounted) {
      _showSnackBar(context, 'Identity metadata exported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _identityMetadataExportErrorMessage(error));
    }
  }
}

Future<List<HostId>?> _showHostSelectionDialog(
  BuildContext context,
  List<HostConfig> hosts, {
  required String title,
  required String description,
}) {
  final selected = {for (final host in hosts) host.id};
  return showDialog<List<HostId>>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final host in hosts)
                          CheckboxListTile(
                            dense: true,
                            value: selected.contains(host.id),
                            title: Text(host.displayName),
                            subtitle: Text(
                              '${host.username}@${host.hostname}:${host.port}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (value ?? false) {
                                  selected.add(host.id);
                                } else {
                                  selected.remove(host.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (selected.length == hosts.length) {
                      selected.clear();
                    } else {
                      selected
                        ..clear()
                        ..addAll(hosts.map((host) => host.id));
                    }
                  });
                },
                child: Text(
                  selected.length == hosts.length ? 'Clear all' : 'Select all',
                ),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(selected.toList(growable: false)),
                child: const Text('Export'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _exportDiagnosticBundle(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Export diagnostic bundle?',
    body:
        'The bundle is redacted and excludes terminal output, commands, hosts, usernames, paths, credentials, and private keys.',
    confirmLabel: 'Export',
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final bundle = await ref
        .read(diagnosticBundleServiceProvider)
        .buildRedactedBundle();
    final location = await getSaveLocation(
      suggestedName: 'serlink-diagnostics.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Serlink Diagnostics', extensions: ['json']),
      ],
    );
    if (location == null) {
      return;
    }
    final file = File(location.path);
    await file.writeAsBytes(bundle.bytes, flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    if (context.mounted) {
      _showSnackBar(context, 'Diagnostic bundle exported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _diagnosticErrorMessage(error));
    }
  }
}

Future<void> _importVaultBackup(BuildContext context, WidgetRef ref) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Serlink Vault Backup', extensions: ['srlkvault']),
    ],
  );
  if (file == null || !context.mounted) {
    return;
  }

  final confirmed = await _confirmDialog(
    context,
    title: 'Import encrypted backup?',
    body:
        'This replaces the local vault header and merges encrypted records from the selected backup.',
    confirmLabel: 'Import',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }

  try {
    final bundle = VaultBackupBundle.fromBytes(await file.readAsBytes());
    await ref.read(vaultBackupServiceProvider).importBackup(bundle);
    ref.invalidate(vaultSessionControllerProvider);
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      _showSnackBar(context, 'Encrypted backup imported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _backupErrorMessage(error));
    }
  }
}

Future<void> _importOpenSshConfig(BuildContext context, WidgetRef ref) async {
  final file = await openFile();
  if (file == null || !context.mounted) {
    return;
  }

  try {
    final service = ref.read(openSshConfigImportServiceProvider);
    final preview = service.preview(
      await file.readAsString(),
      configSourcePath: file.path,
    );
    if (!context.mounted) {
      return;
    }
    if (preview.entries.isEmpty) {
      if (context.mounted) {
        _showSnackBar(context, 'No importable OpenSSH hosts found.');
      }
      return;
    }
    final confirmed = await _showOpenSshConfigImportDialog(context, preview);
    if (!confirmed || !context.mounted) {
      return;
    }
    final result = await service.applyPreview(
      preview,
      defaultUsername: _defaultImportUsername(),
      configSourcePath: file.path,
    );
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      _showSnackBar(
        context,
        'Imported ${result.hostsCreated} hosts'
        '${result.hostsSkipped == 0 ? '' : ', skipped ${result.hostsSkipped}'}.',
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(error));
    }
  }
}

Future<void> _importKnownHosts(BuildContext context, WidgetRef ref) async {
  final file = await openFile();
  if (file == null || !context.mounted) {
    return;
  }

  final confirmed = await _confirmDialog(
    context,
    title: 'Import known_hosts?',
    body:
        'Serlink will import fingerprints that match existing hosts by hostname and port. Hostnames and fingerprints are stored as encrypted vault records.',
    confirmLabel: 'Import',
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final result = await ref
        .read(knownHostsImportServiceProvider)
        .importText(await file.readAsString());
    if (context.mounted) {
      _showSnackBar(
        context,
        'Imported ${result.recordsImported} fingerprints'
        '${result.unmatchedHosts == 0 ? '' : ', ${result.unmatchedHosts} unmatched'}.',
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(error));
    }
  }
}

Future<void> _importOpenSshCertificate(
  BuildContext context,
  WidgetRef ref,
) async {
  final privateKeyFile = await openFile();
  if (privateKeyFile == null || !context.mounted) {
    return;
  }
  final certificateFile = await openFile();
  if (certificateFile == null || !context.mounted) {
    return;
  }

  try {
    final service = ref.read(openSshCertificateImportServiceProvider);
    final draft = OpenSshCertificateImportDraft(
      privateKeyPem: await privateKeyFile.readAsString(),
      certificateText: await certificateFile.readAsString(),
    );
    final preview = service.preview(draft);
    if (!context.mounted) {
      return;
    }
    final confirmedDraft = await _showOpenSshCertificateImportDialog(
      context,
      draft: draft,
      preview: preview,
    );
    if (confirmedDraft == null || !context.mounted) {
      return;
    }
    final identity = await service.importIdentity(confirmedDraft);
    if (context.mounted) {
      _showSnackBar(context, 'Imported ${identity.displayName}.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(error));
    }
  }
}

Future<bool> _showOpenSshConfigImportDialog(
  BuildContext context,
  OpenSshConfigImportResult preview,
) async {
  final warnings = preview.warnings.take(4).toList(growable: false);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Import OpenSSH config?'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${preview.entries.length} host${preview.entries.length == 1 ? '' : 's'} ready to import'
                '${preview.skippedHosts == 0 ? '' : ', ${preview.skippedHosts} skipped'}.',
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final warning in warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      warning.message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (preview.warnings.length > warnings.length)
                  Text(
                    '${preview.warnings.length - warnings.length} more warnings.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
