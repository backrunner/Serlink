# SSH and terminal compatibility audit

Audited on 2026-09-06 with Flutter 3.44.4 / Dart 3.12.2, dartssh2 4.0.0,
and the vendored xterm 4.0.0 branch on macOS.

## Remote coding TUI follow-up (2026-10-16)

Codex 0.162.1 and Claude Code 2.1.299 passed eight real SSH cases: both
applications through tmux 3.7c and GNU screen 5.0.2, at desktop and phone
viewport sizes. The production terminal adapter and ZMODEM-aware path preserved
Chinese/emoji input, arrows, Shift+Tab, slash-command redraws, PTY resizing and
pending editor text after a new SSH connection reattached to the same process.
Shared terminal components were also checked in a native macOS window and an
iPhone 17 / iOS 27 simulator, including the editor above the software keyboard.

The audit fixed unsupported DCS/APC/PM/SOS payloads leaking into terminal cells,
omitted/zero cursor-position parameters, alternate-screen cursor-style recovery,
and Windows/Linux edit shortcuts intercepting remote Ctrl keys. Local editing
now uses Ctrl+Shift chords there; Apple retains Cmd chords. Persistent regression
coverage lives in `test/features/terminal/application/terminal_*_test.dart`.

Use `tmux new-session -A -s coding`, then run `codex` or `claude`. Detach with
Ctrl+B, then D; reconnect with the same command. For screen, use
`screen -U -S coding`, detach with Ctrl+A, then D, and resume with
`screen -U -r coding`. macOS's bundled screen 4.00.03 replaces emoji with U+FFFD
before SSH output; the tested tmux and modern screen preserve it.

The audit passed 138 terminal, SSH and workspace tests, static analysis and a
debug build of the normal macOS application. One-off native probes and
CLI-dependent fixtures were removed after validation; retained tests do not
require installed coding CLIs. Local evidence remains in `build/tui-audit-modern`.
This was local SSH and shared-component validation with dummy loopback model
providers; physical devices, native Windows/Linux, WAN behavior and live model
inference were not verified.

## Immediate terminal connection failure

`TerminalAdapter.attach()` called `stream.transform(Utf8Decoder(...))` on
dartssh2's `Stream<Uint8List>`. Although the application interface exposes
`Stream<List<int>>`, the runtime stream keeps its narrower type, causing:

```text
type 'Utf8Decoder' is not a subtype of type
'StreamTransformer<Uint8List, String>' of 'streamTransformer'
```

This happens after authentication, while attaching stdout (without ZMODEM) or
stderr (with ZMODEM), before the workspace marks the terminal connected. It
explains a successful SSH authentication followed by an immediate terminal
failure. The previous diagnostic event was also misleading: it reported
`ssh.connect.success` before authentication completed.

The decoder now binds to the stream directly, preserving incremental UTF-8
decoding and accepting both runtime stream types. Regression tests exercise
actual `Uint8List` streams with and without ZMODEM.

The incompatible `transform` call was introduced by commit `a8cc62d`, during
the change to incremental UTF-8 decoding. Both dartssh2 2.22.2 and 4.0.0 expose
`Stream<Uint8List>`; the evidence does not attribute this failure to the 4.0
algorithm defaults. No dependency downgrade is needed for this fix.

## Dependency migration checks

| Area | Finding |
| --- | --- |
| dartssh2 version | `c5ea731` upgraded 2.22.2 to 4.0.0 |
| Algorithm defaults | Modern algorithms remain first; explicit legacy fallbacks are present |
| Host fingerprints | Callback supplies a UTF-8 `SHA256:...` string; application decoding matches the real fixture fingerprint |
| Authentication | Password, private-key and keyboard-interactive paths pass protocol tests; invalid credentials and rejected host keys fail correctly |
| Async shutdown | Client and SFTP close futures are awaited; shell exit, transport loss and reconnect pass |
| SFTP timestamps | `accessTime` and `modifyTime` are supplied together as required by 4.0; transfers preserve timestamps |
| xterm | Remains the vendored 4.0.0 branch; Unicode input/output, VT responses, resize, reflow and rendering regressions pass |

Five workspace tests previously used an immediately closed stdout stream while
claiming the fake session was connected. ZMODEM correctly treated this as EOF.
Their fixture now keeps streams alive until the session ends; input assertions
are unchanged.

## Verification and limits

The SSH/terminal interoperability fixture runs an independent AsyncSSH server
and optionally a native OpenSSH server with a disposable key and isolated config.
See [fixture instructions](../test/fixtures/ssh/README.md).

The audited run passed 307 SSH, terminal, MCP and workspace tests, including 14
protocol tests, plus the separate SFTP recursive upload/download, overwrite,
permissions, timestamps and failure-mapping integration test. Static analysis of
changed Dart code passed.

Protocol coverage includes four cipher families, Unicode/stderr, 3,000-line
output bursts, PTY resizing, exit, rejected authentication, jump hosts and
reconnect. Native OpenSSH also verifies actual shell command output and `stty`
window dimensions using a clean `/bin/sh` session.

OS-agent and certificate wrappers have unit coverage, but this run does not
certify live OS-agent/hardware-key access, certificate authentication, actual
ZMODEM file transfers, every legacy algorithm or every remote server. A running
old app must be replaced/restarted before checking Prohosting24-de2 through MCP;
the local protocol tests do not themselves prove that production connection.
