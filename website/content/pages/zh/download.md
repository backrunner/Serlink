---
title: "发行与下载"
description: "发行状态、渠道差异与源码构建。"
---

## 公开发行准备中

Serlink 正在积极开发，目前尚无可在此提供的公开安装包或 App Store 页面。Release 编译与本地检查通过，不代表已经通过 Apple 审核。

可关注 [GitHub Releases](https://github.com/backrunner/Serlink/releases) 获取已发布安装包，也可以[查看源码](https://github.com/backrunner/Serlink)，或先阅读[使用指南](/docs)。

## 平台状态

| 平台 | 当前状态 |
| --- | --- |
| macOS 12 及以上 | 主力桌面平台，准备 App Store、TestFlight 与直接发行。 |
| iOS | 移动端开发与设备验证进行中。 |
| Windows | 已有桌面项目，安装包与实机验收待完成。 |
| Linux | 已有桌面项目，打包与发行版验证待完成。 |

## macOS 发行渠道

**App Store 版**使用 macOS 沙盒，包含远程 SSH/SFTP 与 HTTP MCP，不包含本地 Shell、SSH Agent 认证、OpenSSH 配置集成和 stdio 辅助程序。

**直接发行版**提供这些本地桌面能力。公开安装包需要 Developer ID 签名和公证，完成发布后才会显示安装入口。

## 从源码运行

安装 Flutter **3.47.5** / Dart **3.13.4**、Xcode 与 macOS 桌面工具链，克隆仓库后执行：

```sh
git clone https://github.com/backrunner/Serlink.git
cd Serlink
flutter pub get
flutter run -d macos
```

这会运行开发构建，并非 App Store 安装包。发行操作文档位于仓库 `docs/` 目录，再发行前请阅读[许可](/licenses)。
