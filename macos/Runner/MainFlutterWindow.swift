import Cocoa
import FlutterMacOS

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
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    platformChannel = channel
  }
}
