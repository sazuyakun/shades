import Foundation
import ShadesMedia

// MARK: - AudioError

/// Why sound couldn't be analysed.
public enum AudioError: Error, Equatable {
  case unreadable(MediaError)
}

// MARK: LocalizedError

extension AudioError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unreadable(let error): error.errorDescription
    }
  }
}
