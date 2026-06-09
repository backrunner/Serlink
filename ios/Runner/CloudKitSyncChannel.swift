import CloudKit
import Flutter
import Foundation

/// Bridges the `serlink/cloudkit` method channel to the user's private CloudKit
/// database. The Flutter sync layer writes opaque encrypted objects only.
class CloudKitSyncChannel {
  static let channelName = "serlink/cloudkit"

  private static let recordType = "SerlinkSyncObject"
  private static let pathField = "path"
  private static let dataField = "data"
  private static let containerIdentifier = "iCloud.com.alkinum.serlink"

  private lazy var container = CKContainer(identifier: Self.containerIdentifier)
  private lazy var database = container.privateCloudDatabase
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
      guard let asset = record?[Self.dataField] as? CKAsset,
        let fileURL = asset.fileURL,
        let data = try? Data(contentsOf: fileURL)
      else {
        Self.complete(result, nil)
        return
      }
      Self.complete(result, FlutterStandardTypedData(bytes: data))
    }
  }

  private func writeObject(path: String, data: Data, result: @escaping FlutterResult) {
    let fileURL: URL
    do {
      fileURL = try Self.temporaryFile(for: data)
    } catch {
      Self.complete(result, Self.flutterError(error))
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

  private static func complete(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }

  private static func flutterError(_ error: Error) -> FlutterError {
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
}
