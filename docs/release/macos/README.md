# macOS submission materials

Prepared on 2026-10-11 for Serlink 1.0.0, macOS build 16. App Store Connect
name/subtitle/category updates are saved. Three-language version metadata, screenshots and the privately supplied App Review contact are saved. See the dated report for upload state.

On 2026-10-12, build 16 was resubmitted with incoming-network entitlement
verification steps and an App Review reply. App Store Connect shows Waiting
for Review. See [the entitlement follow-up](network-server-review-2026-10-12.md).

## Files

- `metadata.json`: English, Simplified Chinese, and Japanese App Store fields,
  TestFlight descriptions, and technical app information.
- `review-notes.txt`: copyable English App Review instructions and channel limits.
- `network-server-review-reply.txt`: English reply explaining the incoming-network entitlement; send after saving the corresponding review notes in App Store Connect.
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

The code currently has no developer-operated account, analytics SDK, advertising,
tracking, in-app purchases, or subscriptions. The proposed privacy label is
**Data Not Collected**, based on the code's local processing and user-selected
destinations, with no developer access to user vault content. Reassess if hosted
support, diagnostics ingestion, telemetry, or another collection service is added.
Apple's label concerns off-device data accessible to developers or partners;
on-device processing alone is excluded.
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
| App Review SSH demonstration | No bundled demo server will be supplied by owner choice. Review notes explain reviewer-owned SSH access. The app itself needs no Serlink account. |
| CloudKit schema | Live Production and Development schemas are identical and satisfy the contract; the exported app has Production CloudKit and push entitlements. Two-device Production sync remains unverified. |
| Final archive/export/upload | Build 16 archive and distribution export pass, including strict signature verification. Upload state is recorded in the dated report. |
| Direct macOS release | Use the separate Developer ID/DMG scripts; notarization, stapling and a quarantined clean-Mac check remain required. |

Use `docs/macos_release.md` for the build, export, upload and direct-distribution
runbooks. Do not set the Production-schema confirmation flag merely to bypass
the gate.

## 中文说明

已更新中、英、日搜索名称、副标题、关键词和审核说明，网站升级到 svedocs 0.2.3
并部署。macOS 构建 16 的归档、发行导出、签名与 Production 权限均已验证。
完整测试通过不代替真机跨设备 CloudKit 同步。截图已在原生 macOS 引擎上使用真实生产组件和虚构数据重新捕获，
不代表真实服务器或 CloudKit 运行结果。价格 US$1.99、全球排除法国、获批后自动发布和审核联系人已保存；按所有者要求不提供专用测试服务器，
最终发布与加密申报状态以本次审核报告为准。
