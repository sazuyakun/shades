import Foundation

// MARK: - MediaError

/// Why a media file couldn't be read.
public enum MediaError: Error, Equatable {
  case fileMissing(URL)
  case unreadable(URL)
  case noPictureOrSound(URL)
  case thumbnailFailed(URL)
  case proxyFailed(URL)
  case noAudio(URL)
  case cancelled(URL)
}

// MARK: LocalizedError

extension MediaError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .fileMissing(let url):
      "\(url.lastPathComponent) couldn't be found. It may have been moved or deleted."
    case .unreadable(let url):
      "\(url.lastPathComponent) isn't a video or audio file Shades can read."
    case .noPictureOrSound(let url):
      "\(url.lastPathComponent) has no picture or sound in it."
    case .thumbnailFailed(let url):
      "Couldn't make a thumbnail for \(url.lastPathComponent)."
    case .noAudio(let url):
      "\(url.lastPathComponent) has no sound."
    case .cancelled(let url):
      "Reading \(url.lastPathComponent) was cancelled."
    case .proxyFailed(let url):
      "Couldn't make a lighter editing copy of \(url.lastPathComponent). It will play from the "
        + "original, which may stutter."
    }
  }
}
