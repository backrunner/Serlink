# macOS submission materials

Updated on 2026-10-19 for Serlink 1.0.0, macOS build 17. App Store Connect
name/subtitle/category updates are saved. Three-language version metadata, screenshots and the privately supplied App Review contact are saved. See the dated report for upload state.

On 2026-10-12, build 16 was resubmitted with incoming-network entitlement
verification steps. Apple's 2026-10-18 response now requests an explanation of
Downloads access and populated review access. Build 17 adds an isolated offline
demo and removes the redundant Downloads entitlement. A dedicated live review
account is supplied privately. See [the complete entitlement inventory](entitlements.md);
build 17 has now been uploaded and selected, and the macOS version is Waiting
for Review. See [the October 19 report](review-2026-10-19.md) for evidence.

## Files

- `metadata.json`: English, Simplified Chinese, and Japanese App Store fields,
  TestFlight descriptions, and technical app information.
- `review-notes.txt`: copyable English App Review instructions and channel limits.
- `entitlements.md`: complete entitlement inventory, offline demo and private live-environment design.
- `review-2026-10-19.md`: build 17 archive/export/upload, private review access, entitlement audit and Waiting for Review evidence.
- `network-server-review-reply.txt`: historical October 12 reply for build 16; it does not cover the October 18 rejection. Use the current complete `review-notes.txt` for the replacement build.
- `privacy.html`: multilingual privacy-policy page, paired with the website privacy policy.
- `support.html`: multilingual troubleshooting and support page.
- `encryption.md`: implementation inventory for the export questionnaire.
- `screenshots/{en,zh,ja}/`: five 2560 × 1600 JPEGs per locale, in display order.
- `licenses/`: repository, resolved-package and native CocoaPods license texts.
- `icon-1024.png`: the existing opaque macOS app icon.
- `../review-2026-10-11.md`: dependency changes, findings, and verification.

The screenshot set renders the production Flutter widgets with the App Store
platform capabilities, native macOS Flutter engine and system fonts, and fictional in-memory fixture data.
Terminal text and remote directory contents are examples, not live server results.
Screenshots do not verify a distribution-signed app, CloudKit Production, native
file pickers, or VoiceOver. Review all assets against the final distribution build
before upload. No user vault, real credentials, or private host data are used.

Regenerate on macOS with the selected Flutter 3.47.5 SDK (the capture temporarily adds and restores the integration-test dependency):

```sh
python3 tool/capture_native_macos_store_screenshots.py --flutter /path/to/flutter
python3 tool/check_store_materials.py
```

App Store Mac screenshots must use one of Apple's accepted 16:10 sizes and
contain no transparency. This set uses 2560 × 1600; upload files 01–05 in order
for each matching locale. App previews are optional and are not included.
See [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).

## App Store Connect values

Use the developer-tools category, bundle ID `com.alkinum.serlink`, macOS minimum
version 12.0, and the processed build that matches the final app.
The website source is in `website/`. Metadata points to
`https://serlink.alkinum.com/privacy/` and `https://serlink.alkinum.com/support/`.
Deploy and verify their public HTTPS reachability before submitting those values;
a local build or HTML file is not a valid public App Store URL.

The app has no developer-operated account, advertising SDK, tracking, in-app
purchases or subscriptions. Optional TypeSafe command protection sends complete
commands using the user's account after explicit consent. Without universal
zero-retention terms, the macOS proposal is now **Data Linked to You**: Other
User Content and User ID for App Functionality; Product Interaction for App
Functionality and Analytics (provider usage/telemetry). The macOS manifest and
`metadata.json` match this conservative proposal. See
[the declaration rationale](privacy-declaration.md) for data flows and limits.
The proposal has **not** been saved to App Store Connect. On-device processing
alone is excluded from Apple's collection definition, but BYOK is not an
exemption for retained third-party data.
[Apple privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).

Suggested age-rating inputs: no advertising, messaging/social features, parental
controls, age assurance, in-app unrestricted web browsing, medical advice,
gambling, contests, or rated content provided by Serlink. Server content and
commands belong to the user's own SSH workflow. Complete Apple's current
questionnaire; the resulting rating is determined by App Store Connect.

## Remaining decisions and external gates

| Item | State |
| --- | --- |
| Content rights and account agreements | Content-rights confirmation remains with the account holder; existing trader and Standard Apple EULA settings were retained. |
| Support contact and hosting domain | Support uses the OnFire form. Website is deployed and privacy/support URLs return HTTPS 200; ticket reply delivery is verified separately. |
| Price, territories, release method and date | US$1.99 with US base territory, worldwide except France (174 current territories), automatic release after approval; saved in App Store Connect. |
| Encryption declaration and any jurisdiction-specific documents | The current build questionnaire was answered with standard application-level algorithms and no France distribution; missing-compliance status cleared. Implementation inventory is in `encryption.md`. |
| Distribution rights and EULA | Confirm rights for the AGPL project and bundled dependencies before accepting App Store agreements. No rights declaration has been submitted. |
| App Review demonstration | Hold the lock badge or Settings version label for the isolated offline demo. Dedicated live SSH/SFTP connection details belong only in private review information; do not require reviewers to supply a server. |
| New MCP/model-protection review access | Source remediation is local. Provision a limited TypeSafe review key and supply it privately before the next submission; do not require reviewer purchases. Current live key/access has not been verified. |
| Updated privacy disclosure | Apply the October 29 proposal to App Store Connect and publish the matching multilingual website policy before submission. Neither external operation was performed by the code remediation. |
| CloudKit schema | Live Production and Development schemas are identical and satisfy the contract; the exported app has Production CloudKit and push entitlements. Two-device Production sync remains unverified. |
| Final archive/export/upload | Universal build 17 archive and distribution export pass strict signature verification. Uploaded, processed and resubmitted; Waiting for Review. See the October 19 report. |
| Direct macOS release | Use the separate Developer ID/DMG scripts; notarization, stapling and a quarantined clean-Mac check remain required. |

Use `docs/macos_release.md` for the build, export, upload and direct-distribution
runbooks. Do not set the Production-schema confirmation flag merely to bypass
the gate.

## 中文说明

已更新中、英、日搜索名称、副标题、关键词和审核说明，网站升级到 svedocs 0.2.3
并部署。macOS 构建 17 的 Universal 归档、发行导出、签名与 Production 权限均已验证，
已上传并重新提交，目前等待审核。
完整测试通过不代替真机跨设备 CloudKit 同步。截图已在原生 macOS 引擎上使用真实生产组件和虚构数据重新捕获，
不代表真实服务器或 CloudKit 运行结果。价格 US$1.99、全球排除法国、获批后自动发布和审核联系人已保存；本轮补充离线演示和独立受限审核服务器，凭据仅通过私有审核信息提供，
最终发布与加密申报状态以本次审核报告为准。
