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
