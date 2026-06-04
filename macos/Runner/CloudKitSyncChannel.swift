import CloudKit
import FlutterMacOS
import Foundation
import Security

/// Bridges the `serlink/cloudkit` method channel to the user's private CloudKit
/// database. Each remote object is a `SerlinkSyncObject` record whose
/// `recordName` encodes the object path; payloads are opaque encrypted bytes.
class CloudKitSyncChannel {
  static let channelName = "serlink/cloudkit"

  private static let recordType = "SerlinkSyncObject"
  private static let pathField = "path"
  private static let dataField = "data"
  private static let containerIdentifier = "iCloud.com.alkinum.serlink"

  private lazy var database = CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase
  private var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isAvailable":
      result(Self.hasCloudKitEntitlements)
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

  private func readObject(path: String, result: @escaping FlutterResult) {
    guard Self.hasCloudKitEntitlements else {
      result(Self.unavailableError())
      return
    }
    database.fetch(withRecordID: recordID(for: path)) { record, error in
      if let error = error as? CKError, error.code == .unknownItem {
        result(nil)
        return
      }
      if let error = error {
        result(Self.flutterError(error))
        return
      }
      guard let asset = record?[Self.dataField] as? CKAsset,
        let fileURL = asset.fileURL,
        let data = try? Data(contentsOf: fileURL)
      else {
        result(nil)
        return
      }
      result(FlutterStandardTypedData(bytes: data))
    }
  }

  private func writeObject(path: String, data: Data, result: @escaping FlutterResult) {
    guard Self.hasCloudKitEntitlements else {
      result(Self.unavailableError())
      return
    }
    let fileURL: URL
    do {
      fileURL = try Self.temporaryFile(for: data)
    } catch {
      result(Self.flutterError(error))
      return
    }
    let recordID = recordID(for: path)
    let record = CKRecord(recordType: Self.recordType, recordID: recordID)
    record[Self.pathField] = path as CKRecordValue
    record[Self.dataField] = CKAsset(fileURL: fileURL)
    let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
    operation.savePolicy = .allKeys
    operation.modifyRecordsResultBlock = { saveResult in
      try? FileManager.default.removeItem(at: fileURL)
      switch saveResult {
      case .success:
        result(nil)
      case .failure(let error):
        result(Self.flutterError(error))
      }
    }
    database.add(operation)
  }

  private func deleteObject(path: String, result: @escaping FlutterResult) {
    guard Self.hasCloudKitEntitlements else {
      result(Self.unavailableError())
      return
    }
    database.delete(withRecordID: recordID(for: path)) { _, error in
      if let error = error as? CKError, error.code == .unknownItem {
        result(nil)
        return
      }
      if let error = error {
        result(Self.flutterError(error))
        return
      }
      result(nil)
    }
  }

  private func listObjects(prefix: String?, result: @escaping FlutterResult) {
    guard Self.hasCloudKitEntitlements else {
      result(Self.unavailableError())
      return
    }
    let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
    var paths: [String] = []
    let operation = CKQueryOperation(query: query)
    operation.desiredKeys = [Self.pathField]
    operation.recordMatchedBlock = { _, recordResult in
      if case .success(let record) = recordResult,
        let path = record[Self.pathField] as? String,
        prefix == nil || path.hasPrefix(prefix!)
      {
        paths.append(path)
      }
    }
    operation.queryResultBlock = { queryResult in
      switch queryResult {
      case .success:
        result(paths)
      case .failure(let error):
        result(Self.flutterError(error))
      }
    }
    database.add(operation)
  }

  private func recordID(for path: String) -> CKRecord.ID {
    let encoded =
      path.data(using: .utf8)?.base64EncodedString()
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "=", with: "") ?? path
    return CKRecord.ID(recordName: encoded)
  }

  private static func temporaryFile(for data: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try data.write(to: url, options: .atomic)
    return url
  }

  private static var hasCloudKitEntitlements: Bool {
    entitlementValues("com.apple.developer.icloud-services").contains("CloudKit")
      && entitlementValues("com.apple.developer.icloud-container-identifiers")
        .contains(containerIdentifier)
  }

  private static func entitlementValues(_ name: String) -> [String] {
    guard let task = SecTaskCreateFromSelf(nil),
      let value = SecTaskCopyValueForEntitlement(task, name as CFString, nil)
    else {
      return []
    }
    if let values = value as? [String] {
      return values
    }
    if let value = value as? String {
      return [value]
    }
    return []
  }

  private static func argumentError(_ name: String) -> FlutterError {
    FlutterError(
      code: "sync.cloudkit.invalid_arguments",
      message: "Missing required argument: \(name).",
      details: nil
    )
  }

  private static func unavailableError() -> FlutterError {
    FlutterError(
      code: "sync.cloudkit.unavailable",
      message: "iCloud sync requires a signed app with CloudKit entitlements.",
      details: nil
    )
  }

  private static func flutterError(_ error: Error) -> FlutterError {
    if let ckError = error as? CKError, ckError.code == .notAuthenticated {
      return FlutterError(
        code: "sync.cloudkit.not_authenticated",
        message: "Sign in to iCloud to enable sync.",
        details: error.localizedDescription
      )
    }
    return FlutterError(
      code: "sync.cloudkit.failed",
      message: error.localizedDescription,
      details: nil
    )
  }
}
