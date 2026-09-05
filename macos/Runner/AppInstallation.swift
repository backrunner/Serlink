import Foundation

/// Filesystem operations are separate from the UI so failed copies and upgrades
/// can be tested without launching Flutter or touching /Applications.
enum AppInstallation {
  enum Failure: LocalizedError {
    case invalidApplication, unrelatedDestination, applicationRunning, commandFailed(String)

    var errorDescription: String? {
      switch self {
      case .invalidApplication: return "The application bundle is incomplete. Download the disk image again."
      case .unrelatedDestination: return "The destination is not a matching application and cannot be replaced."
      case .applicationRunning: return "The installed application is running. Quit it and try again."
      case .commandFailed(let message): return message
      }
    }
  }

  static func shouldInstall(enabled: Bool, readOnlyVolume: Bool) -> Bool {
    enabled && readOnlyVolume
  }

  static func destination(
    for source: URL,
    applications: URL = URL(fileURLWithPath: "/Applications", isDirectory: true),
    userApplications: URL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Applications", isDirectory: true)
  ) -> URL {
    let systemDestination = applications.appendingPathComponent(source.lastPathComponent)
    // An existing system install must not silently become a second user install.
    if FileManager.default.fileExists(atPath: systemDestination.path)
      || FileManager.default.isWritableFile(atPath: applications.path) {
      return systemDestination
    }
    return userApplications.appendingPathComponent(source.lastPathComponent)
  }

  static func validateDestination(_ destination: URL, source: URL) throws {
    let manager = FileManager.default
    guard manager.fileExists(atPath: destination.path)
      || (try? destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    else { return }
    guard
      (try destination.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true,
      let sourceID = Bundle(url: source)?.bundleIdentifier,
      Bundle(url: destination)?.bundleIdentifier == sourceID
    else { throw Failure.unrelatedDestination }
  }

  static func run(_ executable: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let errors = Pipe()
    process.standardError = errors
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    // Drain before waiting: ditto can emit more than a pipe buffer of errors.
    let data = errors.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw Failure.commandFailed(
        String(data: data, encoding: .utf8) ?? "The installation command failed."
      )
    }
  }

  static func install(
    source: URL, destination: URL,
    isRunning: (URL) -> Bool,
    copy: (URL, URL) throws -> Void = { source, target in
      try run("/usr/bin/ditto", arguments: [source.path, target.path])
    },
    verify: (URL) throws -> Void = { target in
      try run("/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", target.path])
    }
  ) throws {
    let manager = FileManager.default
    guard let bundle = Bundle(url: source), bundle.bundleIdentifier != nil,
      let executable = bundle.executableURL,
      manager.isExecutableFile(atPath: executable.path)
    else { throw Failure.invalidApplication }
    try validateDestination(destination, source: source)
    guard !isRunning(destination) else { throw Failure.applicationRunning }

    let parent = destination.deletingLastPathComponent()
    try manager.createDirectory(at: parent, withIntermediateDirectories: true)
    let transaction = parent.appendingPathComponent(".serlink-install-\(UUID().uuidString)")
    try manager.createDirectory(at: transaction, withIntermediateDirectories: false)
    let staged = transaction.appendingPathComponent(source.lastPathComponent)
    let backup = transaction.appendingPathComponent("Previous.app")
    var preserveBackup = false
    defer {
      if !preserveBackup { try? manager.removeItem(at: transaction) }
    }

    try copy(source, staged)
    try verify(staged)
    // Recheck after the slow copy, before touching any installed version.
    try validateDestination(destination, source: source)
    guard !isRunning(destination) else { throw Failure.applicationRunning }
    let replacing = manager.fileExists(atPath: destination.path)
    if replacing { try manager.moveItem(at: destination, to: backup) }
    do {
      try manager.moveItem(at: staged, to: destination)
    } catch {
      if replacing {
        do {
          try manager.moveItem(at: backup, to: destination)
        } catch {
          preserveBackup = true
          throw Failure.commandFailed("The previous application is preserved at \(backup.path). \(error.localizedDescription)")
        }
      }
      throw error
    }
  }
}
