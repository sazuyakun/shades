import Foundation
import ShadesMedia

// MARK: - AudioError

/// Why sound couldn't be analysed or written.
public enum AudioError: Error, Equatable {
  case unreadable(MediaError)
  case unwritable(URL)
}

// MARK: LocalizedError

extension AudioError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unreadable(let error): error.errorDescription
    case .unwritable(let url):
      "The cleaned sound couldn't be saved in \(url.deletingLastPathComponent().path). Check "
        + "there's free space."
    }
  }
}
