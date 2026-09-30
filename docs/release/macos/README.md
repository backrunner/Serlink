# macOS submission materials

Prepared on 2026-09-30 for Serlink 1.0.0, macOS build 15. These are local
submission materials; no upload, notarization, or review submission is implied.

## Files

- `metadata.json`: English, Simplified Chinese, and Japanese App Store fields,
  TestFlight descriptions, and technical app information.
- `review-notes.txt`: copyable English App Review instructions and channel limits.
- `privacy.html`: multilingual privacy-policy page, ready to host after inserting
  the operator's support contact.
- `support.html`: multilingual troubleshooting and support page.
- `encryption.md`: implementation inventory for the export questionnaire.
- `screenshots/{en,zh,ja}/`: five 2560 × 1600 JPEGs per locale, in display order.
- `licenses/`: repository, resolved-package and native CocoaPods license texts.
- `icon-1024.png`: the existing opaque macOS app icon.
- `../review-2026-09-30.md`: dependency changes, findings, and verification.

The screenshot set renders the production Flutter widgets with the App Store
platform capabilities, locally installed macOS fonts, and fictional in-memory fixture data.
Terminal text and remote directory contents are examples, not live server results.
Screenshots do not verify a distribution-signed app, CloudKit Production, native
file pickers, or VoiceOver. Review all assets against the final distribution build
before upload. No user vault, real credentials, or private host data are used.

Regenerate on macOS with the selected Flutter 3.47.5 SDK and Python `fonttools`
installed in a virtual environment (font files are not redistributed):

```sh
python3 tool/render_store_screenshots.py /path/to/flutter
python3 tool/check_store_materials.py
```

App Store Mac screenshots must use one of Apple's accepted 16:10 sizes and
contain no transparency. This set uses 2560 × 1600; upload files 01–05 in order
for each matching locale. App previews are optional and are not included.
See [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).

## App Store Connect values

Use the developer-tools category, bundle ID `com.alkinum.serlink`, macOS minimum
version 12.0, and the processed build that matches the final app. Marketing URL
is optional. Supply publicly reachable HTTPS URLs for `privacy.html` and
`support.html`; a local file is not a valid App Store URL.

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
| Developer/legal entity, copyright confirmation, review contact, bank/tax and trader information | Intentionally left to the account holder. |
| Support contact and hosting domain | Pages are prepared locally; insert the operator's public contact and host them, then verify the saved URLs. |
| Price, territories, release method and date | Business choices are unset. No price or availability changes have been made. |
| Encryption declaration and any jurisdiction-specific documents | Technical inventory is prepared in `encryption.md`; complete the current questionnaire and required declarations. |
| Distribution rights and EULA | Confirm rights for the AGPL project and bundled dependencies before accepting App Store agreements. No rights declaration has been submitted. |
| App Review SSH demonstration | Supply a dedicated disposable review server, reachability and non-production credentials in the private review fields if required. The app itself needs no Serlink account. Never commit these credentials. |
| CloudKit schema | Local contract gate passes; Production deployment and two-device sync still require live verification. |
| Final archive/export/upload | Release compilation is verified; App Store distribution export and upload are not performed. Build 15 was not checked against previously uploaded build numbers; increment before the next upload. |
| Direct macOS release | Use the separate Developer ID/DMG scripts; notarization, stapling and a quarantined clean-Mac check remain required. |

Use `docs/macos_release.md` for the build, export, upload and direct-distribution
runbooks. Do not set the Production-schema confirmation flag merely to bypass
the gate.

## 中文说明

材料包含中、英、日商店文案、TestFlight 文案、审核操作说明、隐私和支持页面、
加密实现清单、三套截图及现有图标。所有内容保存在仓库中，尚未发布到网站或
App Store Connect。价格、地区、公开联系方式、审核服务器和加密申报等尚待
账号持有人完成；这些也不能用构建通过来代替。主体、税务、银行及法律承诺信息未填。
