# iOS submission materials

Prepared 2026-10-11 for Serlink 1.0.0 (12), iPhone and iPad from iOS 15.
Three-language ASO/product copy, reviewer instructions, encryption inventory,
privacy/support pages, icon and resolved package/native license records are here.
The full release evidence and confirmed upload status are in
`../review-2026-10-11.md`.

Native screenshots are captured on dedicated iPhone 17 Pro / Pro Max and iPad Pro
13-inch M4 simulators. `screenshots/{iphone,iphone-large,ipad}/{en,zh,ja}/` contains five opaque
JPEGs per locale: hosts, SSH terminal, SFTP, snippets, settings. Sizes are
1206 × 2622 for required medium iPhone, 1320 × 2868 for optional large iPhone,
and 2064 × 2752 for iPad. App Store Connect currently requires the medium
Dynamic Island iPhone slot; large screenshots alone do not satisfy it. These are real native-rendered
production widgets with isolated fictional host, terminal and SFTP data. They do
not establish live server, iCloud, physical-device or distribution runtime behavior.

Regenerate with a dedicated booted simulator (the integration runner uninstalls
its test app afterwards; never use a simulator containing valuable Serlink data):

```sh
python3 tool/capture_ios_store_screenshots.py --flutter /path/to/flutter --device SIMULATOR_UUID --family iphone
python3 tool/capture_ios_store_screenshots.py --flutter /path/to/flutter --device IPAD_SIMULATOR_UUID --family ipad
python3 tool/check_store_materials.py --platform ios
```

The capture tool restores its temporary integration_test dependency and tracked
native project files. Avoid simultaneous source edits/builds while it runs.
Upload screenshots 01–05 to the corresponding locale/device size in App Store
Connect. App previews are optional.

Review contact is saved privately in App Store Connect; do not commit contacts or credentials.
The owner opted out of a bundled review server; notes explain reviewer-owned SSH access.
US$1.99, worldwide except France (174 current territories), automatic release after
approval and the standard-algorithm/no-France encryption answers are saved.
Both processed builds are selected: iOS 12 and macOS 16. Age rating is 4+.
Privacy-label publication and content rights await owner confirmation. Two-device
Production CloudKit runtime remains unverified without a reachable iPhone.
Both platforms share App Store Connect app 6780579821 and bundle ID
com.alkinum.serlink; descriptions reflect their own capabilities. iOS has no desktop
local shells, OS SSH agent or desktop split panes.
