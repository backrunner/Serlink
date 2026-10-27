import Cocoa
import FlutterMacOS
import UserNotifications

/// Only live, in-memory requests can be approved. No credentials or command
/// payloads are stored in notification userInfo or restored after a restart.
final class McpApprovalNotifications: NSObject, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private var channel: FlutterMethodChannel?
  private struct Pending {
    let result: FlutterResult
    let expires: Date
    let directApproval: Bool
    let category: UNNotificationCategory
  }
  private var pending: [String: Pending] = [:]
  private static let prefix = "serlink.mcp."

  func register(with messenger: FlutterBinaryMessenger) {
    center.delegate = self
    // A new app process never revives an old approval.
    center.getDeliveredNotifications { [weak self] notifications in
      let ids = notifications.map { $0.request.identifier }.filter { $0.hasPrefix(Self.prefix) }
      self?.center.removeDeliveredNotifications(withIdentifiers: ids)
    }
    let channel = FlutterMethodChannel(name: "serlink/mcp-approvals", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "status":
        self.status(result)
      case "requestPermission":
        self.center.requestAuthorization(options: [.alert, .sound]) { _, _ in
          self.status(result)
        }
      case "openSettings":
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
          NSWorkspace.shared.open(url)
        }
        result(nil)
      case "show":
        self.show(call.arguments, result: result)
      case "dismiss":
        if let args = call.arguments as? [String: Any], let id = args["id"] as? String {
          self.finish(Self.prefix + id, action: nil)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private func status(_ result: @escaping FlutterResult) {
    center.getNotificationSettings { settings in
      let value: String
      switch settings.authorizationStatus {
      case .authorized, .provisional: value = settings.alertSetting == .enabled ? "authorized" : "denied"
      case .notDetermined: value = "notDetermined"
      case .denied: value = "denied"
      @unknown default: value = "unavailable"
      }
      DispatchQueue.main.async { result(value) }
    }
  }

  private func show(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let rawID = args["id"] as? String,
          let title = args["title"] as? String,
          let body = args["body"] as? String,
          let allow = args["allow"] as? String,
          let deny = args["deny"] as? String,
          let details = args["details"] as? String else {
      result(nil)
      return
    }
    let id = Self.prefix + rawID
    let direct = args["directApproval"] as? Bool ?? false
    let timeout = min(max(args["timeoutMs"] as? Double ?? 60000, 1), 60000) / 1000
    var actions: [UNNotificationAction] = []
    if direct {
      actions.append(UNNotificationAction(identifier: "allow", title: allow, options: [.authenticationRequired]))
    }
    actions.append(UNNotificationAction(identifier: "deny", title: deny, options: []))
    actions.append(UNNotificationAction(identifier: "details", title: details, options: [.foreground]))
    let category = UNNotificationCategory(identifier: id, actions: actions, intentIdentifiers: [], options: [])
    pending[id] = Pending(result: result, expires: Date().addingTimeInterval(timeout), directApproval: direct, category: category)
    center.setNotificationCategories(Set(pending.values.map { $0.category }))
    center.getNotificationSettings { [weak self] settings in
      DispatchQueue.main.async {
        guard let self, self.pending[id] != nil else { return }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
          self.finish(id, action: nil)
          return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = id
        content.sound = .default
        content.userInfo = [:]
        self.center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { [weak self] error in
          DispatchQueue.main.async {
            guard let self else { return }
            if error != nil || self.pending[id] == nil {
              self.finish(id, action: nil)
            }
          }
        }
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
      self?.finish(id, action: nil)
    }
  }

  private func finish(_ id: String, action: String?) {
    let item = pending.removeValue(forKey: id)
    center.removePendingNotificationRequests(withIdentifiers: [id])
    center.removeDeliveredNotifications(withIdentifiers: [id])
    center.setNotificationCategories(Set(pending.values.map { $0.category }))
    item?.result(action)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    DispatchQueue.main.async {
      let live = self.pending[notification.request.identifier] != nil
      completionHandler(live && !NSApp.isActive ? [.banner, .sound, .list] : [])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    DispatchQueue.main.async {
      defer { completionHandler() }
      let id = response.notification.request.identifier
      guard let item = self.pending[id], item.expires > Date() else {
        self.finish(id, action: nil)
        return
      }
      switch response.actionIdentifier {
      case "allow" where item.directApproval:
        self.finish(id, action: "allow")
      case "deny":
        self.finish(id, action: "deny")
      case "details", UNNotificationDefaultActionIdentifier:
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }) {
          window.deminiaturize(nil)
          window.makeKeyAndOrderFront(nil)
        }
        self.finish(id, action: "details")
      default:
        break // Dismissing a banner is not authorization or denial.
      }
    }
  }
}
