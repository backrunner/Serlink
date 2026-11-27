# Linux release

Serlink for Linux ships directly on GitHub Releases, for x64 and arm64:

| File | Purpose |
| --- | --- |
| `Serlink-<version>-linux-<arch>.deb` | Debian/Ubuntu package. Installs to `/opt/serlink`, adds `/usr/bin/serlink`, a desktop entry and icons. |
| `Serlink-<version>-linux-<arch>.tar.gz` | Portable bundle. Extract and run `Serlink/serlink`. |
| `SHA256SUMS-linux-<arch>.txt` | SHA-256 checksums for both files. |

Requirements: glibc 2.34 or later (Ubuntu 22.04, Debian 12, Fedora 35 and
newer), GTK 3.24 and libsecret. CI validates X11 (Xvfb with openbox);
Wayland sessions use GTK's Wayland backend and still need manual QA. A Secret
Service provider (for example GNOME Keyring or KWallet) is used when
available; the vault itself works without one.

```sh
sudo apt install ./Serlink-<version>-linux-x64.deb
# other distributions (install gtk3 and libsecret first)
tar -xzf Serlink-<version>-linux-x64.tar.gz && ./Serlink/serlink
```

Both packages use the `direct` distribution channel: local terminal tabs, SSH
agent authentication and opening local files are enabled. CloudKit sync and
the MCP server are Apple-only.

## Publishing a release

The `Desktop` GitHub Actions workflow (`.github/workflows/desktop.yml`) builds
Linux next to Windows; the same `v<version>` tag publishes all platforms (see
`docs/windows_release.md` for tagging rules). For Linux the workflow:

- runs the unit tests on Linux (reported, not release-blocking),
- runs `integration_test/linux_local_terminal_test.dart` against the real
  pty backend under Xvfb (release-blocking),
- builds x64 (`ubuntu-24.04`) and arm64 (`ubuntu-24.04-arm`) inside an
  `ubuntu:22.04` container with `tool/package_linux.sh`, which keeps the glibc
  requirement at 2.34 and checks that the bundle has the engine, plugin,
  sqlite and pty libraries, the window icon, and no unresolved libraries,
- installs the `.deb` and launches `/usr/bin/serlink` with
  `tool/smoke_test_linux.sh`: first frame, stays alive, resizes from the
  window border, second launch hands off to the first, clean exit when the
  window manager closes the window. Screenshots and the app's diagnostic logs
  are uploaded as the `smoke-test-linux-<arch>` artifact,
- uploads the packages as `serlink-linux-<arch>` and, on tags, attaches them
  to the GitHub Release.

## Building locally on Linux

Install Flutter 3.47.5 (see `.fvmrc`) and the desktop toolchain:

```sh
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev dpkg-dev
flutter pub get
tool/package_linux.sh                         # build + tar.gz + .deb
tool/package_linux.sh --skip-deb              # tar.gz only
tool/smoke_test_linux.sh build/linux/x64/release/bundle/serlink
xvfb-run -a flutter test integration_test/linux_local_terminal_test.dart -d linux
```

Output goes to `build/dist/linux`. The smoke test uses `xdotool`, `wmctrl`, `xvfb`, `xauth`,
`openbox` and `dbus-run-session`. Each run starts its own X11 display and
D-Bus session and uses a temporary application profile.

On macOS, the same build runs in an Ubuntu container (for example with
`container run ubuntu:22.04` or Docker) after installing the packages above
and cloning Flutter at the `.fvmrc` version.

## Signing

Packages are not signed yet. To sign, publish a detached GPG signature of the
`SHA256SUMS-linux-<arch>.txt` files, or move to an apt repository with a
signed `Release` file.

## Linux behaviour notes

- Profile data lives in `~/.local/share/com.alkinum.serlink` (or
  `$XDG_DATA_HOME`). Removing the package keeps it; delete that folder to
  remove the vault and settings.
- Only one Serlink process can own the profile. Release builds register
  `com.alkinum.serlink` on the D-Bus session bus, so launching again activates
  the running window.
- The window has no system frame, like on Windows and macOS. The runner
  provides a 6 px resize border and hands moving and resizing to the window
  manager (`gtk_window_begin_move_drag` / `begin_resize_drag`).
- Local terminal tabs start `$SHELL` (else zsh, bash, sh) as an interactive
  non-login shell with the desktop session environment, like a system
  terminal. Serlink's own `SERLINK_*` variables are not passed on.
- SSH agent authentication uses `SSH_AUTH_SOCK` and also finds agents in
  `$XDG_RUNTIME_DIR` (GNOME Keyring, gpg-agent) and hidden home directories
  (for example `~/.1password/agent.sock`).
- Fonts come from fontconfig. Install CJK fonts (for example `fonts-noto-cjk`)
  to see Chinese and Japanese text in the interface and terminal.
