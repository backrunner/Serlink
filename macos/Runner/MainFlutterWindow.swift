import Cocoa
import FlutterMacOS
import Security

class MainFlutterWindow: NSWindow {
  private static let minimumWindowSize = NSSize(width: 960, height: 600)

  private var windowChannel: FlutterMethodChannel?
  private var platformChannel: FlutterMethodChannel?
  private let cloudKitChannel = CloudKitSyncChannel()
  private var terminationReplyPending = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Match the theme's surface color so the window does not flash black
    // while the engine renders its first frame. Follows system appearance.
    flutterViewController.backgroundColor = NSColor(name: nil) { appearance in
      let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return dark
        ? NSColor(red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
        : NSColor(red: 0xEE / 255.0, green: 0xF1 / 255.0, blue: 0xF6 / 255.0, alpha: 1.0)
    }
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    configureWindowChrome()
    registerWindowChannel(flutterViewController: flutterViewController)
    registerPlatformChannel(flutterViewController: flutterViewController)
    cloudKitChannel.register(with: flutterViewController.engine.binaryMessenger)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }

  private func configureWindowChrome() {
    title = "Serlink"
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    isMovableByWindowBackground = false
    isOpaque = true
    minSize = Self.minimumWindowSize
    backgroundColor = .windowBackgroundColor

    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true
  }

  /// Asks the Dart side whether the app may terminate (Cmd+Q, Dock quit,
  /// logout/shutdown). The Dart side answers through the `replyTerminate`
  /// channel method; a timeout replies affirmatively so the app can always
  /// quit even when the Dart side never responds (e.g. very early quit).
  func requestApplicationTermination() {
    if terminationReplyPending {
      return
    }
    guard let windowChannel else {
      NSApp.reply(toApplicationShouldTerminate: true)
      return
    }
    terminationReplyPending = true
    windowChannel.invokeMethod("requestTerminate", arguments: nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      guard let self, self.terminationReplyPending else { return }
      self.terminationReplyPending = false
      NSApp.reply(toApplicationShouldTerminate: true)
    }
  }

  private func completeApplicationTermination(confirmed: Bool) {
    guard terminationReplyPending else { return }
    terminationReplyPending = false
    NSApp.reply(toApplicationShouldTerminate: confirmed)
  }

  private func registerWindowChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "serlink/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(
          code: "window_unavailable",
          message: "The app window is unavailable.",
          details: nil
        ))
        return
      }

      switch call.method {
      case "activate":
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        if let flutterView = self.contentViewController?.view {
          self.makeFirstResponder(flutterView)
        }
        result(nil)
      case "minimize":
        self.miniaturize(nil)
        result(nil)
      case "toggleMaximize":
        self.zoom(nil)
        result(self.isZoomed)
      case "isMaximized":
        result(self.isZoomed)
      case "close":
        self.close()
        result(nil)
      case "replyTerminate":
        self.completeApplicationTermination(
          confirmed: (call.arguments as? Bool) ?? false
        )
        result(nil)
      case "startDrag":
        if let event = NSApp.currentEvent {
          self.performDrag(with: event)
        }
        result(nil)
      case "setWindowDraggingEnabled":
        self.isMovable = (call.arguments as? Bool) ?? true
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = channel
  }

  private func registerPlatformChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "serlink/platform",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "displayName":
        result(Host.current().localizedName ?? ProcessInfo.processInfo.hostName)
      case "sshAgentLocations":
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleURL)
        DispatchQueue.global(qos: .utility).async {
          let locations = Self.sshAgentLocations(running: running)
          DispatchQueue.main.async { result(locations) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    platformChannel = channel
  }

  // Only public application/signing metadata is read. No provider database,
  // keychain, credentials, private keys or vendor API is consulted.
  private static func sshAgentLocations(running: [URL]) -> [String: Any] {
    let manager = FileManager.default
    let home = manager.homeDirectoryForCurrentUser
    var applications = Set(running)
    for root in [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")] {
      let contents = (try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
      applications.formUnion(contents.filter { $0.pathExtension == "app" })
    }
    var roots: [[String: String]] = []
    var seen = Set<String>()
    func add(_ url: URL, name: String) {
      if seen.insert(url.path).inserted { roots.append(["path": url.path, "name": name]) }
    }
    for application in applications.sorted(by: { $0.path < $1.path }).prefix(256) {
      guard let bundle = Bundle(url: application), let identifier = bundle.bundleIdentifier,
        !identifier.contains("/"), !identifier.contains("..") else { continue }
      let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? application.deletingPathExtension().lastPathComponent
      let data = home.appendingPathComponent("Library/Containers/\(identifier)/Data")
      add(data, name: name)
      var code: SecStaticCode?
      guard SecStaticCodeCreateWithPath(application as CFURL, [], &code) == errSecSuccess,
        let code else { continue }
      var information: CFDictionary?
      guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
        let values = information as? [String: Any],
        let entitlements = values[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
        let groups = entitlements["com.apple.security.application-groups"] as? [String] else { continue }
      for group in groups where !group.contains("/") && !group.contains("..") {
        let root = home.appendingPathComponent("Library/Group Containers/\(group)")
        add(root.appendingPathComponent("t"), name: name)
        add(root, name: name)
      }
    }
    return ["home": home.path, "roots": roots]
  }
}
