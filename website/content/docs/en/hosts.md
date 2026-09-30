---
title: "Hosts & identities"
description: "Organize servers, authentication and trusted host keys."
order: 2
---

## Connection profiles

Save the hostname, SSH port and username in a host profile. A display name and tags help you find the right machine. Passwords, private keys and OpenSSH certificates belong to reusable identities in the vault.

Choose a jump host when the target is only reachable through a bastion. Confirm that each hop has valid credentials and that the target can be reached from the previous hop.

## Trust a server

Before accepting a new host key, compare its fingerprint with one supplied by the server administrator. If a known key changes, investigate the change before replacing the saved key. Manage trusted keys in **Settings → Known hosts**.

## Import existing configuration

The direct macOS build can import and reconcile OpenSSH configuration. This feature is unavailable in the App Store channel, along with SSH-agent authentication. App Store builds still support configured password and key identities.

For ordinary profile edits, return to **Hosts**. For credentials, use **Settings → Credentials** after unlocking the vault. [Vault locking](/docs/vault) blocks new credential resolution.
