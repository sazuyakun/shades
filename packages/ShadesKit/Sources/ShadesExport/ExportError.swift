import Foundation
import ShadesEngine

// MARK: - ExportError

/// Why an export couldn't be made.
public enum ExportError: Error, Equatable {
  case renderFailed(EngineError)
  case unwritable(URL)
  case encodingFailed
  case nothingToExport(String)
  case cancelled
}

// MARK: LocalizedError

extension ExportError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .renderFailed(let error): error.errorDescription

    case .unwritable(let url):
      "\(url.lastPathComponent) couldn't be saved in \(url.deletingLastPathComponent().path). "
        + "Check the folder exists, you can write to it, and there's free space."

    case .encodingFailed:
      "The video couldn't be encoded. Try again; if it keeps failing, try H.264 instead of HEVC."

    case .nothingToExport(let what): "There's nothing to export: \(what)."

    case .cancelled: "The export was cancelled."
    }
  }
}
