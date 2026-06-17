import CloudKit
import Flutter
import Foundation
import UIKit

/// Bridges the `serlink/cloudkit` method channel to the user's private CloudKit
/// database. The Flutter sync layer writes opaque encrypted objects only.
class CloudKitSyncChannel: NSObject, FlutterStreamHandler {
  static let channelName = "serlink/cloudkit"
  static let eventsChannelName = "serlink/cloudkit/events"

  private static let recordType = "SerlinkSyncObject"
  private static let pathField = "path"
  private static let dataField = "data"
  private static let containerIdentifier = "iCloud.com.alkinum.serlink"
  private static let subscriptionID = "serlink-sync-objects"

  private static weak var activeChannel: CloudKitSyncChannel?
  private static var hasPendingRemoteChange = false
  private static let timestampFormatter = ISO8601DateFormatter()

  private lazy var container = CKContainer(identifier: Self.containerIdentifier)
  private lazy var database = container.privateCloudDatabase
  private var channel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private var subscriptionRequested = false

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    let eventChannel = FlutterEventChannel(name: Self.eventsChannelName, binaryMessenger: messenger)
    eventChannel.setStreamHandler(self)
    self.channel = channel
    self.eventChannel = eventChannel
    Self.activeChannel = self
    UIApplication.shared.registerForRemoteNotifications()
    ensureRemoteChangeSubscription()
    flushPendingRemoteChanges()
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    UIApplication.shared.registerForRemoteNotifications()
    ensureRemoteChangeSubscription()
    flushPendingRemoteChanges()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  @discardableResult
  func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
      notification.subscriptionID == Self.subscriptionID
    else {
      return false
    }
    emitRemoteChange(source: "push")
    return true
  }

  @discardableResult
  static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
      notification.subscriptionID == subscriptionID
    else {
      return false
    }
    DispatchQueue.main.async {
      if let channel = activeChannel {
        channel.emitRemoteChange(source: "push")
      } else {
        hasPendingRemoteChange = true
      }
    }
    return true
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isAvailable":
      isAvailable(result: result)
    case "readObject":
      guard let path = arguments["path"] as? String else {
        result(Self.argumentError("path"))
        return
      }
      readObject(path: path, result: result)
    case "writeObject":
      guard let path = arguments["path"] as? String,
        let data = (arguments["data"] as? FlutterStandardTypedData)?.data
      else {
        result(Self.argumentError("path/data"))
        return
      }
      writeObject(path: path, data: data, result: result)
    case "writeObjectIfUnchanged":
      guard let path = arguments["path"] as? String,
        let data = (arguments["data"] as? FlutterStandardTypedData)?.data
      else {
        result(Self.argumentError("path/data"))
        return
      }
      let expectedData = (arguments["expectedData"] as? FlutterStandardTypedData)?.data
      writeObjectIfUnchanged(path: path, data: data, expectedData: expectedData, result: result)
    case "deleteObject":
      guard let path = arguments["path"] as? String else {
        result(Self.argumentError("path"))
        return
      }
      deleteObject(path: path, result: result)
    case "listObjects":
      listObjects(prefix: arguments["prefix"] as? String, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func isAvailable(result: @escaping FlutterResult) {
    container.accountStatus { status, error in
      if let error = error {
        Self.complete(result, Self.flutterError(error))
        return
      }
      Self.complete(result, status == .available)
    }
  }

  private func readObject(path: String, result: @escaping FlutterResult) {
    database.fetch(withRecordID: recordID(for: path)) { record, error in
      if let error = error as? CKError, error.code == .unknownItem {
        Self.complete(result, nil)
        return
      }
      if let error = error {
        Self.complete(result, Self.flutterError(error))
        return
      }
      guard let data = Self.assetData(from: record) else {
        Self.complete(result, nil)
        return
      }
      Self.complete(result, FlutterStandardTypedData(bytes: data))
    }
  }

  private func writeObject(path: String, data: Data, result: @escaping FlutterResult) {
    let record = CKRecord(recordType: Self.recordType, recordID: recordID(for: path))
    saveObject(path: path, data: data, record: record, savePolicy: .allKeys, result: result)
  }

  private func writeObjectIfUnchanged(
    path: String,
    data: Data,
    expectedData: Data?,
    result: @escaping FlutterResult
  ) {
    let recordID = recordID(for: path)
    database.fetch(withRecordID: recordID) { [weak self] record, error in
      guard let self else {
        Self.complete(result, Self.unavailableError())
        return
      }
      if let error = error as? CKError, error.code == .unknownItem {
        guard expectedData == nil else {
          Self.complete(result, Self.conflictError())
          return
        }
        let newRecord = CKRecord(recordType: Self.recordType, recordID: recordID)
        self.saveObject(path: path, data: data, record: newRecord, savePolicy: .ifServerRecordUnchanged, result: result)
        return
      }
      if let error = error {
        Self.complete(result, Self.flutterError(error))
        return
      }
      guard let record = record else {
        Self.complete(result, Self.conflictError())
        return
      }
      guard let expectedData = expectedData,
        let currentData = Self.assetData(from: record),
        currentData == expectedData
      else {
        Self.complete(result, Self.conflictError())
        return
      }
      self.saveObject(path: path, data: data, record: record, savePolicy: .ifServerRecordUnchanged, result: result)
    }
  }

  private func saveObject(
    path: String,
    data: Data,
    record: CKRecord,
    savePolicy: CKModifyRecordsOperation.RecordSavePolicy,
    result: @escaping FlutterResult
  ) {
    let fileURL: URL
    do {
      fileURL = try Self.temporaryFile(for: data)
    } catch {
      Self.complete(result, Self.flutterError(error))
      return
    }
    record[Self.pathField] = path as CKRecordValue
    record[Self.dataField] = CKAsset(fileURL: fileURL)
    let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
    operation.savePolicy = savePolicy
    operation.modifyRecordsResultBlock = { saveResult in
      try? FileManager.default.removeItem(at: fileURL)
      switch saveResult {
      case .success:
        Self.complete(result, nil)
      case .failure(let error):
        Self.complete(result, Self.flutterError(error))
      }
    }
    database.add(operation)
  }

  private func deleteObject(path: String, result: @escaping FlutterResult) {
    database.delete(withRecordID: recordID(for: path)) { _, error in
      if let error = error as? CKError, error.code == .unknownItem {
        Self.complete(result, nil)
        return
      }
      if let error = error {
        Self.complete(result, Self.flutterError(error))
        return
      }
      Self.complete(result, nil)
    }
  }

  private func listObjects(prefix: String?, result: @escaping FlutterResult) {
    let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
    var paths: [String] = []
    var recordError: Error?
    var completed = false
    let lock = NSLock()

    func appendPath(_ path: String) {
      lock.lock()
      paths.append(path)
      lock.unlock()
    }

    func setRecordError(_ error: Error) {
      lock.lock()
      if recordError == nil {
        recordError = error
      }
      lock.unlock()
    }

    func snapshot() -> (paths: [String], error: Error?) {
      lock.lock()
      defer { lock.unlock() }
      return (paths, recordError)
    }

    func completeOnce(_ value: Any?) {
      lock.lock()
      if completed {
        lock.unlock()
        return
      }
      completed = true
      lock.unlock()
      Self.complete(result, value)
    }

    func addOperation(_ operation: CKQueryOperation) {
      operation.desiredKeys = [Self.pathField]
      operation.recordMatchedBlock = { _, recordResult in
        switch recordResult {
        case .success(let record):
          guard let path = record[Self.pathField] as? String else {
            return
          }
          if let prefix, !path.hasPrefix(prefix) {
            return
          }
          appendPath(path)
        case .failure(let error):
          setRecordError(error)
        }
      }
      operation.queryResultBlock = { queryResult in
        switch queryResult {
        case .success(let cursor):
          if let error = snapshot().error {
            completeOnce(Self.flutterError(error))
            return
          }
          if let cursor = cursor {
            addOperation(CKQueryOperation(cursor: cursor))
          } else {
            completeOnce(snapshot().paths)
          }
        case .failure(let error):
          completeOnce(Self.flutterError(error))
        }
      }
      database.add(operation)
    }

    addOperation(CKQueryOperation(query: query))
  }

  private func ensureRemoteChangeSubscription() {
    if subscriptionRequested {
      return
    }
    subscriptionRequested = true
    saveRemoteChangeSubscription()
  }

  private func saveRemoteChangeSubscription() {
    let options: CKQuerySubscription.Options = [
      .firesOnRecordCreation,
      .firesOnRecordUpdate,
      .firesOnRecordDeletion,
    ]
    let subscription = CKQuerySubscription(
      recordType: Self.recordType,
      predicate: NSPredicate(value: true),
      subscriptionID: Self.subscriptionID,
      options: options
    )
    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = notificationInfo
    let operation = CKModifySubscriptionsOperation(
      subscriptionsToSave: [subscription],
      subscriptionIDsToDelete: nil
    )
    operation.modifySubscriptionsResultBlock = { [weak self] result in
      if case .failure = result {
        DispatchQueue.main.async {
          self?.subscriptionRequested = false
        }
      }
    }
    database.add(operation)
  }

  private func emitRemoteChange(source: String) {
    DispatchQueue.main.async {
      guard let eventSink = self.eventSink else {
        Self.hasPendingRemoteChange = true
        return
      }
      eventSink(Self.remoteChangeEvent(source: source))
    }
  }

  private func flushPendingRemoteChanges() {
    DispatchQueue.main.async {
      guard Self.hasPendingRemoteChange, let eventSink = self.eventSink else {
        return
      }
      Self.hasPendingRemoteChange = false
      eventSink(Self.remoteChangeEvent(source: "pending"))
    }
  }

  private func recordID(for path: String) -> CKRecord.ID {
    let encoded =
      path.data(using: .utf8)?.base64EncodedString()
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "=", with: "") ?? path
    return CKRecord.ID(recordName: encoded)
  }

  private static func assetData(from record: CKRecord?) -> Data? {
    guard let asset = record?[dataField] as? CKAsset,
      let fileURL = asset.fileURL
    else {
      return nil
    }
    return try? Data(contentsOf: fileURL)
  }

  private static func temporaryFile(for data: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try data.write(to: url, options: .atomic)
    return url
  }

  private static func argumentError(_ name: String) -> FlutterError {
    FlutterError(
      code: "sync.cloudkit.invalid_arguments",
      message: "Missing required argument: \(name).",
      details: nil
    )
  }

  private static func conflictError() -> FlutterError {
    FlutterError(
      code: "sync.provider.conflict",
      message: "Remote sync data changed while syncing.",
      details: nil
    )
  }

  private static func unavailableError() -> FlutterError {
    FlutterError(
      code: "sync.cloudkit.unavailable",
      message: "iCloud sync is unavailable.",
      details: nil
    )
  }

  private static func complete(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }

  private static func remoteChangeEvent(source: String) -> [String: Any] {
    [
      "type": "remoteChange",
      "source": source,
      "receivedAt": timestampFormatter.string(from: Date()),
    ]
  }

  private static func flutterError(_ error: Error) -> FlutterError {
    if isConflict(error) {
      return conflictError()
    }
    if let ckError = error as? CKError {
      switch ckError.code {
      case .notAuthenticated:
        return FlutterError(
          code: "sync.cloudkit.not_authenticated",
          message: "Sign in to iCloud to enable sync.",
          details: error.localizedDescription
        )
      case .permissionFailure, .badContainer:
        return FlutterError(
          code: "sync.cloudkit.unavailable",
          message: "iCloud sync requires a signed app with CloudKit entitlements.",
          details: error.localizedDescription
        )
      default:
        break
      }
    }
    return FlutterError(
      code: "sync.cloudkit.failed",
      message: error.localizedDescription,
      details: nil
    )
  }

  private static func isConflict(_ error: Error) -> Bool {
    guard let ckError = error as? CKError else {
      return false
    }
    if ckError.code == .serverRecordChanged {
      return true
    }
    if let partialErrors = ckError.partialErrorsByItemID {
      return partialErrors.values.contains { isConflict($0) }
    }
    return false
  }
}
