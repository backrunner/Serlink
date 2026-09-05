import Cocoa

enum DirectAppInstaller {
  private static func localized(_ english: String, _ chinese: String, _ japanese: String) -> String {
    let language = Locale.preferredLanguages.first ?? "en"
    if language.hasPrefix("zh") { return chinese }
    if language.hasPrefix("ja") { return japanese }
    return english
  }

  /// Also detects Gatekeeper's read-only App Translocation volume, without
  /// relying on /Volumes paths or private Security.framework APIs.
  static func runIfNeeded() -> Bool {
    let source = Bundle.main.bundleURL
    let enabled = Bundle.main.object(forInfoDictionaryKey: "SerlinkDMGInstallerEnabled") as? String == "YES"
    let readOnly = (try? source.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly == true
    guard AppInstallation.shouldInstall(enabled: enabled, readOnlyVolume: readOnly) else { return false }

    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.applicationIconImage = NSWorkspace.shared.icon(forFile: source.path)
    app.activate(ignoringOtherApps: true)
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Serlink"
    let destination = AppInstallation.destination(for: source)

    do {
      try AppInstallation.validateDestination(destination, source: source)
      while isRunning(destination) {
        let alert = NSAlert()
        alert.messageText = localized("Quit \(name) to install", "请先退出 \(name)", "\(name) を終了してください")
        alert.informativeText = localized(
          "Save your work and quit the installed app, then try again.",
          "请保存工作并退出已安装的应用，然后重试。",
          "作業を保存してインストール済みのアプリを終了し、再試行してください。")
        alert.addButton(withTitle: localized("Try Again", "重试", "再試行"))
        alert.addButton(withTitle: localized("Cancel", "取消", "キャンセル"))
        guard alert.runModal() == .alertFirstButtonReturn else { return true }
      }
      if FileManager.default.fileExists(atPath: destination.path) {
        let alert = NSAlert()
        alert.messageText = localized("Replace \(name)?", "替换 \(name)？", "\(name) を置き換えますか？")
        alert.informativeText = localized(
          "An app already exists at \(destination.path). Replace it with this version? Your saved data will be kept.",
          "\(destination.path) 已有应用。是否替换为此版本？已保存的数据会保留。",
          "\(destination.path) にアプリがあります。このバージョンに置き換えますか？保存済みデータは保持されます。")
        alert.addButton(withTitle: localized("Replace and Open", "替换并打开", "置き換えて開く"))
        alert.addButton(withTitle: localized("Cancel", "取消", "キャンセル"))
        guard alert.runModal() == .alertFirstButtonReturn else { return true }
      }

      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 440, height: 148),
        styleMask: [.titled], backing: .buffered, defer: false)
      panel.title = localized("Installing \(name)", "正在安装 \(name)", "\(name) をインストール中")
      panel.isReleasedWhenClosed = false
      let label = NSTextField(labelWithString: localized(
        "Installing and opening the app…", "正在安装并打开应用…", "アプリをインストールして開いています…"))
      label.frame = NSRect(x: 28, y: 94, width: 384, height: 24)
      let location = NSTextField(labelWithString: destination.path)
      location.frame = NSRect(x: 28, y: 64, width: 384, height: 20)
      location.textColor = .secondaryLabelColor
      location.lineBreakMode = .byTruncatingMiddle
      let progress = NSProgressIndicator(frame: NSRect(x: 28, y: 30, width: 384, height: 12))
      progress.style = .bar
      progress.isIndeterminate = true
      progress.startAnimation(nil)
      panel.contentView?.addSubview(label)
      panel.contentView?.addSubview(location)
      panel.contentView?.addSubview(progress)
      panel.center()

      var installationError: Error?
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try AppInstallation.install(source: source, destination: destination, isRunning: isRunning)
          DispatchQueue.main.async {
            let configuration = NSWorkspace.OpenConfiguration()
            // The mounted instance has the same bundle ID; launch the exact URL
            // as a new instance so LaunchServices cannot reactivate this copy.
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, error in
              DispatchQueue.main.async {
                installationError = error
                NSApp.stopModal()
              }
            }
          }
        } catch {
          DispatchQueue.main.async {
            installationError = error
            NSApp.stopModal()
          }
        }
      }
      app.runModal(for: panel)
      panel.close()
      if let installationError { throw installationError }
    } catch {
      let alert = NSAlert()
      alert.alertStyle = .critical
      alert.messageText = localized("Unable to install or open \(name)", "无法安装或打开 \(name)", "\(name) をインストールまたは起動できません")
      alert.informativeText = localized(
        "Installation location: \(destination.path)\n\n\(error.localizedDescription)\n\nYou can try again, or copy the app to Applications in Finder.",
        "安装位置：\(destination.path)\n\n\(error.localizedDescription)\n\n请重试，或在 Finder 中将应用复制到“应用程序”。",
        "インストール先: \(destination.path)\n\n\(error.localizedDescription)\n\n再試行するか、Finder でアプリケーションフォルダにコピーしてください。")
      alert.addButton(withTitle: localized("Close", "关闭", "閉じる"))
      alert.runModal()
    }
    return true
  }

  private static func isRunning(_ destination: URL) -> Bool {
    let path = destination.resolvingSymlinksInPath().standardizedFileURL.path
    return NSWorkspace.shared.runningApplications.contains {
      $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        && $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path == path
    }
  }
}
