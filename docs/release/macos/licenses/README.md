# License review inputs

`Serlink-LICENSE.txt` is the repository license. `resolved-packages.txt` contains
license/notice files from every resolved Dart package, including build/test tools.
`macos-pods-acknowledgements.plist` is CocoaPods' generated native dependency
acknowledgement file for the macOS build. These preserve texts for rights review;
they do not establish that App Store agreements are compatible with each license.
Confirm distribution rights before submission. No macOS font binaries are included.

Serlink bundles JetBrainsMono Nerd Font Mono from Nerd Fonts v3.4.0 under the SIL
Open Font License 1.1. The original font notices and upstream Nerd Fonts license
are in `assets/fonts/jetbrains_mono_nerd/` and included in the app's Flutter license
registry. See that directory's README for pinned source URLs and file checksums.

Flutter SDK subpackages flutter_localizations, flutter_test and flutter_web_plugins
are covered by the Flutter repository license included under PACKAGE: flutter in
resolved-packages.txt; they have no separate root license file.
