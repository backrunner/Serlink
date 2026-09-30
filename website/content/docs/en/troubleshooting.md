---
title: "Troubleshooting"
description: "Distinguish network, authentication, transfer and vault failures."
order: 8
---

## SSH connection failures

Check DNS/IP, port reachability, VPN or jump-host routing, username and identity. Verify a changed host key with the server administrator. A successful authentication followed by a shell failure is different from an unreachable server.

## File transfer failures

Check the remote account’s permissions, the selected local folder, free disk space and destination conflicts. Refresh the remote listing after another tool changes it. Retry after fixing the cause; inspect the final queue status.

## Sync or vault issues

Confirm the destination, network, TLS trust and service permissions. Unlock the vault before syncing. Back up before resetting it; keep recovery material separate. Disabling sync does not remove remote copies.

## Send a useful report

In **Settings → Diagnostic logs**, export the redacted logs. Include app version, OS version, the failing action and the approximate time. Review the export before sharing; terminal output and command contents are not automatically included.

Contact [support](/support). Never include passwords, private keys, recovery keys or MCP tokens.
