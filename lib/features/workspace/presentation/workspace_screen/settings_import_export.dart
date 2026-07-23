part of '../workspace_screen.dart';

Future<void> _exportVaultBackup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final confirmed = await _confirmDialog(
    context,
    title: l10n.exportVaultBackupTitle,
    body: l10n.exportVaultBackupBody,
    confirmLabel: l10n.settingsExportAction,
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final bundle = await ref.read(vaultBackupServiceProvider).exportBackup();
    final exported = await ref
        .read(documentGatewayProvider)
        .exportBytes(
          bytes: Uint8List.fromList(bundle.toBytes()),
          suggestedName: 'serlink-vault-backup.srlkvault',
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Serlink Vault Backup',
              extensions: ['srlkvault'],
            ),
          ],
          mimeType: 'application/json',
        );
    if (!exported) {
      return;
    }
    if (context.mounted) {
      _showSnackBar(context, l10n.backupExportedSnack);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _backupErrorMessage(l10n, error));
    }
  }
}

Future<void> _exportHostMetadata(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
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
      _showSnackBar(context, l10n.noHostsAvailableExportSnack);
      return;
    }
    final selectedHostIds = await _showHostSelectionDialog(
      context,
      hosts,
      title: l10n.exportHostMetadataTitle,
      description: l10n.exportHostMetadataBody,
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
    final exported = await ref
        .read(documentGatewayProvider)
        .exportBytes(
          bytes: Uint8List.fromList(bundle.toBytes()),
          suggestedName: 'serlink-host-metadata.json',
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Serlink Host Metadata', extensions: ['json']),
          ],
          mimeType: 'application/json',
        );
    if (!exported) {
      return;
    }
    if (context.mounted) {
      _showSnackBar(context, l10n.hostMetadataExportedSnack);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, l10n.hostMetadataExportFailedSnack);
    }
  }
}

Future<void> _exportOpenSshConfig(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
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
      _showSnackBar(context, l10n.noHostsAvailableExportSnack);
      return;
    }
    final selectedHostIds = await _showHostSelectionDialog(
      context,
      hosts,
      title: l10n.exportOpenSshConfigTitle,
      description: l10n.exportOpenSshConfigBody,
    );
    if (selectedHostIds == null ||
        selectedHostIds.isEmpty ||
        !context.mounted) {
      return;
    }
    final decision = await ref
        .read(securityModalServiceProvider)
        .confirmExport(
          ExportPreview(
            title: l10n.exportOpenSshConfigTitle,
            encrypted: false,
            sensitiveFields: [
              l10n.exportFieldHostnames,
              l10n.exportFieldUsernames,
              l10n.exportFieldPorts,
              l10n.exportFieldJumpHostAliases,
              l10n.exportFieldConnectionSettings,
            ],
          ),
        );
    if (decision != ExportDecision.confirm || !context.mounted) {
      return;
    }
    final bundle = await ref
        .read(openSshConfigExportServiceProvider)
        .export(selectedHostIds: selectedHostIds);
    final exported = await ref
        .read(documentGatewayProvider)
        .exportString(
          contents: bundle.contents,
          suggestedName: 'serlink-openssh-config.sshconfig',
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'OpenSSH Config',
              extensions: ['sshconfig', 'config', 'txt'],
            ),
          ],
          mimeType: 'text/plain',
        );
    if (!exported) {
      return;
    }
    if (context.mounted) {
      _showSnackBar(context, l10n.openSshConfigExportedSnack);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _openSshConfigExportErrorMessage(l10n, error));
    }
  }
}

Future<void> _exportIdentityMetadata(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final confirmed = await ref
      .read(securityModalServiceProvider)
      .confirmExport(
        ExportPreview(
          title: l10n.exportIdentityMetadataTitle,
          encrypted: false,
          sensitiveFields: [
            l10n.exportFieldDisplayNames,
            l10n.exportFieldUsernameHints,
            l10n.exportFieldPublicKeyFingerprints,
            l10n.exportFieldCertificatePrincipals,
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
    final exported = await ref
        .read(documentGatewayProvider)
        .exportBytes(
          bytes: Uint8List.fromList(bundle.toBytes()),
          suggestedName: 'serlink-identity-metadata.json',
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Serlink Identity Metadata',
              extensions: ['json'],
            ),
          ],
          mimeType: 'application/json',
        );
    if (!exported) {
      return;
    }
    if (context.mounted) {
      _showSnackBar(context, l10n.identityMetadataExportedSnack);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _identityMetadataExportErrorMessage(l10n, error));
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
  return showSerlinkDialog<List<HostId>>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return SerlinkDialog(
            maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
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
                          SerlinkCheckboxListTile(
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
              SerlinkTextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.cancelAction),
              ),
              SerlinkTextButton(
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
                  selected.length == hosts.length
                      ? context.l10n.clearAllAction
                      : context.l10n.selectAllAction,
                ),
              ),
              SerlinkFilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(selected.toList(growable: false)),
                child: Text(context.l10n.settingsExportAction),
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
  final l10n = context.l10n;
  try {
    final bundle = await ref
        .read(diagnosticBundleServiceProvider)
        .buildRedactedBundle();
    final exported = await ref
        .read(documentGatewayProvider)
        .exportBytes(
          bytes: Uint8List.fromList(bundle.bytes),
          suggestedName: 'serlink-diagnostics.zip',
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Serlink Diagnostics', extensions: ['zip']),
          ],
          mimeType: 'application/zip',
        );
    if (!exported) {
      return;
    }
    if (context.mounted) {
      _showSnackBar(context, l10n.diagnosticBundleExportedSnack);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _diagnosticErrorMessage(l10n, error));
    }
  }
}

Future<void> _importVaultBackup(BuildContext context, WidgetRef ref) async {
  final file = await ref
      .read(documentGatewayProvider)
      .pickUploadFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Serlink Vault Backup', extensions: ['srlkvault']),
        ],
      );
  if (file == null || !context.mounted) {
    return;
  }

  final confirmed = await _confirmDialog(
    context,
    title: context.l10n.importEncryptedBackupTitle,
    body: context.l10n.importEncryptedBackupBody,
    confirmLabel: context.l10n.importAction,
    destructive: true,
  );
  if (!confirmed) {
    return;
  }

  try {
    final bundle = VaultBackupBundle.fromBytes(
      await File(file.path).readAsBytes(),
    );
    await ref.read(vaultBackupServiceProvider).importBackup(bundle);
    ref.invalidate(vaultSessionControllerProvider);
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      _showSnackBar(context, context.l10n.backupImportedSnack);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _backupErrorMessage(context.l10n, error));
    }
  }
}

Future<void> _importOpenSshConfig(BuildContext context, WidgetRef ref) async {
  final file = await ref.read(documentGatewayProvider).pickUploadFile();
  if (file == null || !context.mounted) {
    return;
  }

  try {
    final service = ref.read(openSshConfigImportServiceProvider);
    final configSourcePath =
        ref.read(platformCapabilitiesProvider).stableLocalFilePaths
        ? file.path
        : null;
    final preview = service.preview(
      await File(file.path).readAsString(),
      configSourcePath: configSourcePath,
    );
    if (!context.mounted) {
      return;
    }
    if (preview.entries.isEmpty) {
      if (context.mounted) {
        _showSnackBar(context, context.l10n.noImportableOpenSshHostsSnack);
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
      configSourcePath: configSourcePath,
    );
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      final l10n = context.l10n;
      _showSnackBar(
        context,
        result.hostsSkipped == 0
            ? l10n.openSshHostsImportedSnack(result.hostsCreated)
            : l10n.openSshHostsImportedSkippedSnack(
                result.hostsCreated,
                result.hostsSkipped,
              ),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(context.l10n, error));
    }
  }
}

Future<void> _importKnownHosts(BuildContext context, WidgetRef ref) async {
  final file = await ref.read(documentGatewayProvider).pickUploadFile();
  if (file == null || !context.mounted) {
    return;
  }

  final confirmed = await _confirmDialog(
    context,
    title: context.l10n.importKnownHostsTitle,
    body: context.l10n.importKnownHostsBody,
    confirmLabel: context.l10n.importAction,
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final result = await ref
        .read(knownHostsImportServiceProvider)
        .importText(await File(file.path).readAsString());
    if (context.mounted) {
      final l10n = context.l10n;
      _showSnackBar(
        context,
        result.unmatchedHosts == 0
            ? l10n.knownHostsImportedSnack(result.recordsImported)
            : l10n.knownHostsImportedUnmatchedSnack(
                result.recordsImported,
                result.unmatchedHosts,
              ),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(context.l10n, error));
    }
  }
}

Future<void> _importOpenSshCertificate(
  BuildContext context,
  WidgetRef ref,
) async {
  final privateKeyFile = await ref
      .read(documentGatewayProvider)
      .pickUploadFile(
        acceptedTypeGroups: const [XTypeGroup(label: 'SSH Private Key')],
      );
  if (privateKeyFile == null || !context.mounted) {
    return;
  }
  final certificateFile = await ref
      .read(documentGatewayProvider)
      .pickUploadFile(
        acceptedTypeGroups: const [XTypeGroup(label: 'OpenSSH Certificate')],
      );
  if (certificateFile == null || !context.mounted) {
    return;
  }

  try {
    final service = ref.read(openSshCertificateImportServiceProvider);
    final draft = OpenSshCertificateImportDraft(
      privateKeyPem: await File(privateKeyFile.path).readAsString(),
      certificateText: await File(certificateFile.path).readAsString(),
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
      _showSnackBar(
        context,
        context.l10n.identityImportedSnack(identity.displayName),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(context.l10n, error));
    }
  }
}

Future<bool> _showOpenSshConfigImportDialog(
  BuildContext context,
  OpenSshConfigImportResult preview,
) async {
  final warnings = preview.warnings.take(4).toList(growable: false);
  final result = await showSerlinkDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return SerlinkDialog(
        maxWidth: _adaptiveDialogWidth(context, _dialogWidthSmall),
        title: Text(context.l10n.importOpenSshConfigTitle),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.skippedHosts == 0
                    ? context.l10n.openSshConfigHostsReady(
                        preview.entries.length,
                      )
                    : context.l10n.openSshConfigHostsReadySkipped(
                        preview.entries.length,
                        preview.skippedHosts,
                      ),
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                SerlinkAlert.warning(
                  title: context.l10n.importWarningsTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < warnings.length; i++) ...[
                        if (i > 0) const SizedBox(height: 4),
                        Text(
                          warnings[i].message,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.tokens.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ],
                      if (preview.warnings.length > warnings.length) ...[
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.moreWarnings(
                            preview.warnings.length - warnings.length,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.tokens.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          SerlinkTextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          SerlinkFilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.importAction),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
