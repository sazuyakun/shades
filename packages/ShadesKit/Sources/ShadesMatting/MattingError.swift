import Foundation

// MARK: - MattingError

/// Why a cut-out (matte) couldn't be made.
public enum MattingError: Error, Equatable {
  case unreadable(URL)
  case unwritable(URL)
  case segmentationFailed
  case cancelled
}

// MARK: LocalizedError

extension MattingError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unreadable(let url):
      "\(url.lastPathComponent) couldn't be read to cut out its subject. Check it still plays."

    case .unwritable(let url):
      "The cut-out couldn't be saved in \(url.deletingLastPathComponent().path). Check there's "
        + "free space."

    case .segmentationFailed:
      "The subject couldn't be found in the picture. Try another engine."

    case .cancelled:
      "Making the cut-out was cancelled."
    }
  }
}
