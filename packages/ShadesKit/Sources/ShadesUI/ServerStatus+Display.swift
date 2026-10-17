import ShadesMCP
import SwiftUI

/// How Claude's connection status reads on screen, shared by the title bar pill and Settings.
extension ServerStatus {
  var title: String {
    if case .failed = self {
      "Claude offline"
    } else {
      "Claude"
    }
  }

  var color: Color {
    switch self {
    case .starting: Theme.faintText
    case .ready: Theme.positive
    case .failed: Theme.negative
    }
  }

  var message: String {
    switch self {
    case .starting:
      "Getting ready for Claude…"

    case .ready:
      "Claude can connect through the shades-mcp relay (apps/mcp). Direct HTTP comes in M2."

    case .failed(let error):
      error.errorDescription ?? "Claude can't connect."
    }
  }
}
