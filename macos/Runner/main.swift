import Cocoa

// Run before NSApplicationMain loads MainMenu.xib and starts the Flutter engine.
// The mounted copy must never open the vault or start the MCP server.
if DirectAppInstaller.runIfNeeded() {
  exit(EXIT_SUCCESS)
}

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
