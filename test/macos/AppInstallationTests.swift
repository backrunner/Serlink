import Foundation
import XCTest

final class AppInstallationTests: XCTestCase {
  private var root: URL!
  private var source: URL!
  private var destination: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    source = root.appendingPathComponent("Disk/Serlink (Dev).app")
    destination = root.appendingPathComponent("Applications/Serlink (Dev).app")
    try makeApp(source, content: "new")
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: root)
  }

  private func makeApp(_ url: URL, content: String, identifier: String = "com.alkinum.serlink") throws {
    let contents = url.appendingPathComponent("Contents")
    let executable = contents.appendingPathComponent("MacOS/serlink")
    try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
    let plist: [String: Any] = ["CFBundleIdentifier": identifier, "CFBundleExecutable": "serlink", "CFBundlePackageType": "APPL"]
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
      .write(to: contents.appendingPathComponent("Info.plist"))
    try Data(content.utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
  }

  private func content(_ app: URL) throws -> String {
    try String(contentsOf: app.appendingPathComponent("Contents/MacOS/serlink"), encoding: .utf8)
  }

  private func install(isRunning: @escaping (URL) -> Bool = { _ in false }) throws {
    try AppInstallation.install(source: source, destination: destination, isRunning: isRunning, verify: { _ in })
  }

  func testOnlyEnabledReadOnlyLaunchesInstall() {
    XCTAssertTrue(AppInstallation.shouldInstall(enabled: true, readOnlyVolume: true))
    XCTAssertFalse(AppInstallation.shouldInstall(enabled: false, readOnlyVolume: true))
    XCTAssertFalse(AppInstallation.shouldInstall(enabled: true, readOnlyVolume: false))
    XCTAssertFalse(AppInstallation.shouldInstall(enabled: false, readOnlyVolume: false))
  }

  func testFreshInstallPreservesSourceAndBundleName() throws {
    try install()
    XCTAssertEqual(try content(destination), "new")
    XCTAssertEqual(try content(source), "new")
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.deletingLastPathComponent().path), ["Serlink (Dev).app"])
  }

  func testUpgradeReplacesOnlyApp() throws {
    try makeApp(destination, content: "old")
    let data = root.appendingPathComponent("vault.db")
    try Data("vault".utf8).write(to: data)
    try install()
    XCTAssertEqual(try content(destination), "new")
    XCTAssertEqual(try String(contentsOf: data, encoding: .utf8), "vault")
  }

  func testFailedCopyPreservesOldApp() throws {
    try makeApp(destination, content: "old")
    XCTAssertThrowsError(try AppInstallation.install(source: source, destination: destination, isRunning: { _ in false }, copy: { _, target in
      try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
      throw AppInstallation.Failure.commandFailed("Disk full")
    }, verify: { _ in }))
    XCTAssertEqual(try content(destination), "old")
  }

  func testInvalidSignaturePreservesOldApp() throws {
    try makeApp(destination, content: "old")
    XCTAssertThrowsError(try AppInstallation.install(source: source, destination: destination, isRunning: { _ in false }, verify: { _ in
      throw AppInstallation.Failure.commandFailed("Invalid signature")
    }))
    XCTAssertEqual(try content(destination), "old")
  }

  func testRunningAppIsNeverReplaced() throws {
    try makeApp(destination, content: "old")
    XCTAssertThrowsError(try install(isRunning: { _ in true }))
    var checks = 0
    XCTAssertThrowsError(try install(isRunning: { _ in checks += 1; return checks == 2 }))
    XCTAssertEqual(checks, 2)
    XCTAssertEqual(try content(destination), "old")
  }

  func testUnrelatedAppIsNeverReplaced() throws {
    try makeApp(destination, content: "unrelated", identifier: "org.example.unrelated")
    XCTAssertThrowsError(try install())
    XCTAssertEqual(try content(destination), "unrelated")
  }

  func testSymlinkDestinationIsNeverFollowed() throws {
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: source)
    XCTAssertThrowsError(try install())
    XCTAssertEqual(try content(source), "new")
  }

  func testFailedFinalMoveRestoresOldApp() throws {
    try makeApp(destination, content: "old")
    XCTAssertThrowsError(try AppInstallation.install(source: source, destination: destination, isRunning: { _ in false }, verify: { staged in
      // Simulate the staged bundle disappearing before the final rename.
      try FileManager.default.removeItem(at: staged)
    }))
    XCTAssertEqual(try content(destination), "old")
  }

  func testUserApplicationsFallbackAndExistingSystemInstall() throws {
    let missing = root.appendingPathComponent("Unavailable")
    let user = root.appendingPathComponent("UserApplications")
    XCTAssertEqual(AppInstallation.destination(for: source, applications: missing, userApplications: user), user.appendingPathComponent(source.lastPathComponent))
    try makeApp(destination, content: "old")
    XCTAssertEqual(AppInstallation.destination(for: source, applications: destination.deletingLastPathComponent(), userApplications: user).path, destination.path)
  }
}
