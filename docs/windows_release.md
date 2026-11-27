# Windows release

Serlink for Windows ships directly on GitHub Releases as:

| File | Purpose |
| --- | --- |
| `Serlink-<version>-windows-x64-setup.exe` | Installer. Per-user by default (no admin prompt); can install for all users. Adds a Start menu entry and an uninstaller. |
| `Serlink-<version>-windows-x64.zip` | Portable bundle. Unzip and run `Serlink\serlink.exe`. |
| `SHA256SUMS-windows-x64.txt` | SHA-256 checksums for both files. |

Requirements: Windows 10 version 1809 (build 17763) or later, x64. Windows on
Arm runs the x64 build under emulation. The Visual C++ runtime is bundled, so
no redistributable install is needed.

The installer and portable build use the `direct` distribution channel: local
terminal tabs, SSH agent authentication and opening local files are enabled.
CloudKit sync and the MCP server are Apple-only.

## Publishing a release

The `Desktop` GitHub Actions workflow (`.github/workflows/desktop.yml`) does
the Windows part on `windows-latest`; the same tag also publishes the macOS
DMG (see `docs/macos_release.md`) and the Linux packages (see
`docs/linux_release.md`):

1. Make sure `version:` in `pubspec.yaml` matches the release (for example
   `1.2.0+7`). The `+build` number becomes the fourth part of the Windows file
   version and must be 65535 or lower.
2. Push a tag `v<version>`, for example `v1.2.0`. A pre-release label is
   allowed (`v1.2.0-beta.1`) and marks the GitHub Release as a pre-release.
   The version before the label must match `pubspec.yaml` or the run fails.
3. The workflow:
   - runs the Windows unit tests (reported, not release-blocking),
   - runs `integration_test/windows_local_terminal_test.dart` against the
     real ConPTY backend (release-blocking),
   - builds with `tool/package_windows.ps1`, which verifies that the bundle
     contains the engine, the plugin and sqlite DLLs and the VC++ runtime,
   - launches the packaged app with `tool/smoke_test_windows.ps1`: first
     frame, stays alive, second launch hands off to the first, clean exit.
     A screenshot and the app's diagnostic logs are uploaded as the
     `smoke-test` artifact,
   - creates the GitHub Release for the tag with generated notes, or uploads
     to the existing release (for example one that already has the macOS
     DMG) and replaces files with the same names.

Pushes to `main`, pull requests and manual runs (`workflow_dispatch`) run the
same build and tests and upload the packages as the `serlink-windows-x64`
workflow artifact without publishing anything.

## Building locally on Windows

Install Flutter 3.47.5 (see `.fvmrc`), Visual Studio 2022 with the "Desktop
development with C++" workload, and [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```powershell
flutter pub get
pwsh tool/package_windows.ps1                 # build + zip + installer
pwsh tool/package_windows.ps1 -SkipInstaller  # zip only
pwsh tool/smoke_test_windows.ps1 -Exe build\windows\x64\runner\Release\serlink.exe
flutter test integration_test/windows_local_terminal_test.dart -d windows
```

Output goes to `build\dist\windows`.

## Code signing

Builds are not code signed yet, so SmartScreen shows "Windows protected your
PC" on first launch (More info > Run anyway). To sign, add a signing step
between the build and installer steps in `tool/package_windows.ps1`: sign
`serlink.exe` and the DLLs in the bundle, then sign the generated setup
executable (Inno Setup `SignTool=` or `signtool sign` afterwards).

## Windows behaviour notes

- Profile data lives in `%APPDATA%\BackRunner\Serlink`. Uninstalling keeps it;
  delete that folder to remove the vault and settings.
- Only one Serlink process can own the profile. Release builds activate the
  running window when launched again; setup and uninstall ask to close it.
- Local terminal tabs start PowerShell 7 when installed, otherwise Windows
  PowerShell, otherwise `%ComSpec%`, with the user's environment (Serlink's
  own `SERLINK_*` variables are not passed on). They use ConPTY through the
  patched `third_party/flutter_pty`.
- SSH agent authentication uses the Windows OpenSSH agent pipe
  (`\\.\pipe\openssh-ssh-agent`), which 1Password also provides.
