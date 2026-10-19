import Foundation
import ShadesMedia

// MARK: - AudioError

/// Why sound couldn't be analysed, separated or written.
public enum AudioError: Error, Equatable {
  case unreadable(MediaError)
  case unwritable(URL)
  case modelUnavailable
  case separationFailed
  case cancelled
}

// MARK: LocalizedError

extension AudioError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unreadable(let error): error.errorDescription
    case .modelUnavailable:
      "The stem separation model couldn't be loaded. Download it again from Settings."
    case .separationFailed:
      "The sound couldn't be separated. Try again; if it keeps failing, restart Shades."
    case .cancelled: "Stem separation was cancelled."
    case .unwritable(let url):
      "The cleaned sound couldn't be saved in \(url.deletingLastPathComponent().path). Check "
        + "there's free space."
    }
  }
}
