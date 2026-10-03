import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let cloudKitChannel = CloudKitSyncChannel()
  private var platformChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    engineBridge.applicationRegistrar.register(
      NativeTabBarFactory(messenger: messenger), withId: "serlink/native_tab_bar"
    )
    registerPlatformChannel(with: messenger)
    cloudKitChannel.register(with: messenger)
  }

  private func registerPlatformChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "serlink/platform", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "displayName":
        result(UIDevice.current.name)
      case "openLocalFile":
        Self.openLocalFile(call.arguments, result: result)
      case "supportsLiquidGlassTabBar":
        // Liquid Glass requires linking with the iOS 26 SDK or later.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
          result(true)
        } else {
          result(false)
        }
        #else
        result(false)
        #endif
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    platformChannel = channel
  }

  private static func openLocalFile(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let arguments = arguments as? [String: Any],
          let path = arguments["path"] as? String, !path.isEmpty else {
      result(FlutterError(code: "invalid_path", message: "A file path is required.", details: nil))
      return
    }
    let url = URL(fileURLWithPath: path)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: url.path) else {
      result(FlutterError(code: "file_unavailable", message: "The file is unavailable.", details: nil))
      return
    }
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    guard var presenter = window?.rootViewController else {
      result(FlutterError(code: "no_presenter", message: "No active window.", details: nil))
      return
    }
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    guard !(presenter is UIActivityViewController), !presenter.isBeingDismissed else {
      result(FlutterError(code: "presentation_busy", message: "File actions are already open.", details: nil))
      return
    }
    // Passing the file URL keeps large downloads out of the method channel and
    // offers compatible apps together with system actions such as Save to Files.
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(controller, animated: true) { result(true) }
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if cloudKitChannel.handleRemoteNotification(userInfo) {
      completionHandler(.newData)
      return
    }
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }
}
