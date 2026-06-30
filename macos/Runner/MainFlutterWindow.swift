import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let minimumWindowSize = NSSize(width: 960, height: 600)

  private var windowChannel: FlutterMethodChannel?
  private var platformChannel: FlutterMethodChannel?
  private let cloudKitChannel = CloudKitSyncChannel()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
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
