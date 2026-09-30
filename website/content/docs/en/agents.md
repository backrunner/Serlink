---
title: "MCP & agent access"
description: "Authorize an external agent to use app-owned SSH sessions."
order: 7
---

## How access works

On macOS, Serlink exposes an authenticated loopback MCP endpoint. External agents request sessions through it; you approve access in the app. Passwords and private keys remain in the vault instead of being handed to the agent.

Serlink does not include an AI model. An authorized agent may process terminal contents using its own provider and configuration. Review that agent’s data practices.

## Connect a client

Open **Settings → MCP / Agent access**. Copy the HTTP configuration displayed by the running app into your MCP client. The address and token belong to that app run; do not share the token.

```json
{
  "mcpServers": {
    "serlink": {
      "type": "http",
      "url": "http://127.0.0.1:<port>/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

Both macOS channels support HTTP access. The separate stdio helper is available only in the direct distribution. Use the helper configuration copied by the app rather than guessing its installation path.

## Approve and revoke

Unlock the vault before opening a host session. The first client/host request needs your approval. Risky commands can require further confirmation and some destructive patterns are blocked; these checks are not a complete safety guarantee.

Grants are held in memory and expire when the app quits. Revoke them and close agent sessions in **Settings → Agent access**. An execution response is settled screen text, not a verified process exit code; long-running commands may need a longer timeout.
