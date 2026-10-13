import Foundation

// MARK: - MediaError

/// Why a media file couldn't be read.
public enum MediaError: Error, Equatable {
  case fileMissing(URL)
  case unreadable(URL)
  case noVideo(URL)
  case thumbnailFailed(URL)
}

// MARK: LocalizedError

extension MediaError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .fileMissing(let url):
      "\(url.lastPathComponent) couldn't be found. It may have been moved or deleted."
    case .unreadable(let url):
      "\(url.lastPathComponent) isn't a video Shades can read."
    case .noVideo(let url):
      "\(url.lastPathComponent) has no video in it."
    case .thumbnailFailed(let url):
      "Couldn't make a thumbnail for \(url.lastPathComponent)."
    }
  }
}
