---
title: "ダウンロード"
description: "公開状況、配布方式、ソースからの実行。"
---

## 公開リリースを準備中

Serlink は開発中です。現在、このページで案内できる公開インストーラーや App Store ページはありません。Release のビルドとローカル確認は Apple 審査の完了を意味しません。

公開パッケージは [GitHub Releases](https://github.com/backrunner/Serlink/releases) をご確認ください。[ソース](https://github.com/backrunner/Serlink)や[使い方](/docs)も読めます。

## プラットフォームの状況

| プラットフォーム | 現在の状況 |
| --- | --- |
| macOS 12 以降 | 主なデスクトップ対象。App Store、TestFlight、直接配布を準備中。 |
| iOS | モバイル開発と実機検証を進行中。 |
| Windows | デスクトッププロジェクトあり。インストーラーと実機確認は未完了。 |
| Linux | デスクトッププロジェクトあり。パッケージとディストリビューション検証は未完了。 |

## macOS の配布方式

**App Store 版**は macOS のサンドボックスを使用し、リモート SSH/SFTP と HTTP MCP を提供します。ローカル Shell、SSH Agent、OpenSSH 設定統合、stdio ヘルパーは含みません。

**直接配布版**はこれらのローカル機能を提供します。公開インストーラーは Developer ID 署名と公証が必要で、公開後にリンクを案内します。

## ソースから実行する

Flutter **3.47.5** / Dart **3.13.4**、Xcode、macOS デスクトップのツールを準備します。

```sh
git clone https://github.com/backrunner/Serlink.git
cd Serlink
flutter pub get
flutter run -d macos
```

これは開発ビルドであり、App Store インストーラーではありません。配布の手順はリポジトリの `docs/` にあります。再配布前に[ライセンス](/licenses)を確認してください。
