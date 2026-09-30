---
title: "Get started"
description: "Create your vault and open your first SSH connection."
order: 1
---

## Create a workspace

Open Serlink and create a vault with a passphrase. Save the recovery key somewhere private and separate from the device. It is needed if you lose the passphrase. If a vault already exists, unlock it instead.

You do not need a Serlink account. You do need an SSH server and authentication details supplied by its administrator.

## Add a host

In **Hosts**, add a name, hostname or IP address, port, username and authentication method. Reuse an identity when several hosts use the same password or key. See [host setup](/docs/hosts).

## Open a terminal

Choose the host’s **Terminal** action. For a new server, verify the host-key fingerprint against a trusted source before accepting it. After authentication, the session opens in the workspace.

A harmless first command on a Unix-like server is:

```sh
pwd
```

Use **SFTP** on the same host to [browse its files](/docs/sftp). To understand encryption, recovery and locking, read the [vault guide](/docs/vault).

## Check the platform

The macOS App Store and direct builds have different local capabilities. Public distribution is being prepared. See [availability](/download) before looking for an installer.
