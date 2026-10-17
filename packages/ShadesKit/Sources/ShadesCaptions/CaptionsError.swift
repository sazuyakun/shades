import Foundation

// MARK: - CaptionsError

/// Why a transcript couldn't be made.
public enum CaptionsError: Error, Equatable {
  case modelDownloadFailed(model: String)
  case modelLoadFailed(model: String)
  case audioUnreadable(URL)
  case noAudio(URL)
  case noSpeech
  case transcriptionFailed
  case cancelled
}

// MARK: LocalizedError

extension CaptionsError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .modelDownloadFailed(let model):
      "The \(model) speech model couldn't be downloaded. Check your internet connection and free "
        + "disk space, then try again."

    case .modelLoadFailed(let model):
      "The \(model) speech model couldn't be loaded. Try again; if it keeps failing, delete it in "
        + "Settings and download it again."

    case .audioUnreadable(let url):
      "The sound in \(url.lastPathComponent) couldn't be read. Check the file still plays."

    case .noAudio(let url):
      "\(url.lastPathComponent) has no sound to transcribe."

    case .noSpeech:
      "No speech was found. Check the clip has someone talking, or try a larger model."

    case .transcriptionFailed:
      "The transcript couldn't be made. Try again, or pick a different model."

    case .cancelled:
      "Transcribing was cancelled."
    }
  }
}
