---
title: "Encrypted sync"
description: "Choose WebDAV or iCloud and review conflicts."
order: 6
---

## Choose a destination

In **Settings**, configure your own WebDAV endpoint or use iCloud on supported Apple builds when it is available. The app synchronizes encrypted manifests and records. Vault keys are not uploaded by the sync service; service providers may still process operational metadata.

Unlock the same vault on another device using its passphrase or recovery material. Sync is optional and is not a Serlink-operated cloud account.

## Review a conflict

If local and remote changes conflict, inspect the records in the sync review interface. Choose the version you intend to keep. Do not reset a workspace merely to dismiss a conflict; retain an encrypted backup first.

## Turn sync off or remove data

Disabling sync stops future app sync. It does not erase copies already stored remotely. Use the app’s remote-data controls or your service provider to remove those copies, and manage backups separately.

For connection, TLS or permission errors, read [troubleshooting](/docs/troubleshooting).
