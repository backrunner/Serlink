import Cocoa
import FlutterMacOS

class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard
      let window = NSApp.windows.first(where: { $0 is MainFlutterWindow })
        as? MainFlutterWindow
    else {
      return .terminateNow
    }
    window.requestApplicationTermination()
    return .terminateLater
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    NSApplication.shared.registerForRemoteNotifications()
  }

  override func application(
    _ application: NSApplication,
    didReceiveRemoteNotification userInfo: [String: Any]
  ) {
    if CloudKitSyncChannel.handleRemoteNotification(userInfo) {
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo)
  }
}
