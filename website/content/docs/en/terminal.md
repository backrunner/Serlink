---
title: "Terminal workspace"
description: "Tabs, desktop splits, search, reconnecting and snippets."
order: 3
---

## Keep sessions together

Open a terminal from a host. Switch between session tabs without opening another window. On desktop, split a terminal tab into panes when you need to compare machines or keep a long-running task visible.

Search the terminal buffer to locate previous output. Reconnect an interrupted session in place; a reconnect creates a new remote shell rather than resuming a terminated server process.

## Terminal fonts

Serlink includes **JetBrainsMono Nerd Font Mono** and uses it by default for new terminal settings on every platform. Nerd Font and Powerline icons work without installing a font separately.

In **Settings → Terminal → Font**, choose the built-in font or another installed Nerd Font. You can also enter an installed font family in the custom font field. Existing font choices are preserved; the built-in font fills in missing icons. Per-host terminal profiles can use a different font from the global setting.

## Reuse commands

Save frequently used commands in **Snippets**. Choose the target session and review the command before sending it. Snippets can require confirmation. Pasting multiple lines can also trigger a paste guard.

## Local and remote tools

Direct desktop builds include local terminal tabs. App Store builds omit local shells. SSH forwarding and desktop ZMODEM workflows depend on the session and server configuration; they do not replace ordinary [SFTP transfers](/docs/sftp).

## When a connection fails

Check the host, port, username, identity and network path. A sleeping device or network change may require a reconnect. See [troubleshooting](/docs/troubleshooting) for diagnostic stages.
