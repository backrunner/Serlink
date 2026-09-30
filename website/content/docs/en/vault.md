---
title: "Vault & recovery"
description: "Understand passphrases, recovery, locking and backups."
order: 5
---

## What the vault protects

Host profiles, identities, snippets and workspace records are stored as encrypted vault data. The application uses authenticated encryption, with a key derived from your passphrase. Device secrets use system secure storage.

Downloaded files, plaintext metadata exports and remote server contents are outside this protection. See the [privacy policy](/privacy) for data handling.

## Recovery and backups

Save the recovery key when creating the vault. Keep it separate from the device and from the backup itself. The developer cannot recover an unknown passphrase without the recovery material.

Use **Settings → Import / Export** to create an encrypted backup. Store it somewhere safe and keep an independent copy before resetting or replacing a workspace.

## Lock and biometric unlock

Locking prevents new access to vault credentials. Existing SSH/SFTP connections and transfers may keep running; close them separately when you need to end access.

On supported devices, biometric unlock protects a random device key. It does not save the vault passphrase. You can enable or remove it in **Settings**, and always retain your passphrase or recovery key.

## Background privacy

The optional background privacy setting covers the app’s content when it moves out of the foreground. It is a visual privacy control and does not replace vault locking or closing a connection.
