import AppKit
import UserNotifications

// MARK: - ExportNotifier

/// Tells the user an export finished: a soft chime and a Mac notification, which reveals the
/// file in the Finder when clicked.
final class ExportNotifier: NSObject {

  /// Chimes and posts the notification for the file at `url`.
  func finished(_ url: URL) {
    NSSound(named: "Glass")?.play()
    // why: notifications need an app bundle; tests and command-line runs only chime.
    guard Bundle.main.bundleIdentifier != nil else {
      return
    }
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    let content = UNMutableNotificationContent()
    content.title = "Export finished"
    content.body = url.lastPathComponent
    content.userInfo = ["path": url.path]
    let request = UNNotificationRequest(identifier: url.path, content: content, trigger: nil)
    Task {
      // why: without permission, or if posting fails, the chime has already told the user.
      guard (try? await center.requestAuthorization(options: [.alert])) == true else {
        return
      }
      try? await center.add(request)
    }
  }

}

// MARK: UNUserNotificationCenterDelegate

extension ExportNotifier: UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent _: UNNotification,
  ) async -> UNNotificationPresentationOptions {
    .banner
  }

  nonisolated func userNotificationCenter(
    _: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
  ) async {
    guard let path = response.notification.request.content.userInfo["path"] as? String else {
      return
    }
    await MainActor.run {
      NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
    }
  }
}
