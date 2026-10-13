import Foundation
import ShadesCore

// MARK: - CommandError

/// Why a command couldn't be applied.
public enum CommandError: Error, Equatable {
  case mediaAlreadyAdded(Media.ID)
  case mediaNotFound(Media.ID)
  case trackNotFound(index: Int)
}

// MARK: LocalizedError

extension CommandError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .mediaAlreadyAdded:
      "This media is already in the project."
    case .mediaNotFound(let id):
      "No media with ID \(id) is in the project. Import it first."
    case .trackNotFound(let index):
      "The timeline has no track number \(index + 1)."
    }
  }
}
