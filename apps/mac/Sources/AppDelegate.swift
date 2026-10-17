import AppKit
import ShadesUI

/// Owns the workspace and saves it before Shades quits.
final class AppDelegate: NSObject, NSApplicationDelegate {
  let workspace = Workspace()

  func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
    Task {
      await workspace.prepareToQuit()
      NSApp.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}
