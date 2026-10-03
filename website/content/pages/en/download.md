---
title: "Downloads"
description: "Availability, distribution channels and source builds."
---

## Public release is being prepared

Serlink is in active development. There is currently no public installer or App Store listing to link here. Release compilation and local checks do not mean the app has passed Apple review.

Follow [GitHub releases](https://github.com/backrunner/Serlink/releases) for published packages. You can also [read the source](https://github.com/backrunner/Serlink) or begin with the [usage guide](/docs).

## Platform status

| Platform | Current status |
| --- | --- |
| macOS 12 or later | Primary desktop target; App Store, TestFlight and direct release preparation. |
| iOS | Mobile development and device validation in progress. |
| Windows | Desktop project present; installer and real-device acceptance pending. |
| Linux | Desktop project present; packaging and distribution testing pending. |

## macOS channels

The **App Store** build uses the macOS sandbox. It includes remote SSH/SFTP and HTTP MCP, but omits local terminal shells, SSH-agent authentication, OpenSSH config integration and the stdio helper.

The **direct** build includes those local desktop capabilities. A published direct installer must be Developer ID signed and notarized. Availability of an installer is shown only after that release is published.

## Build from source

Install Flutter **3.47.5** / Dart **3.13.4**, Xcode and the macOS desktop toolchain. Clone the repository, then:

```sh
git clone https://github.com/backrunner/Serlink.git
cd Serlink
flutter pub get
flutter run -d macos
```

This launches a development build, not an App Store installer. Distribution runbooks are in the repository’s `docs/` directory. See [licenses](/licenses) before redistributing.
