import Foundation

// MARK: - EngineError

/// Why the engine couldn't build, play or render the timeline.
public enum EngineError: Error, Equatable {
  case timelineEmpty
  case mediaMissing(UUID)
  case mediaUnreadable(URL)
  case compositionFailed
  case metalUnavailable
  case renderFailed
  case frameUnavailable(seconds: Double)
  case imageEncodingFailed
}

// MARK: LocalizedError

extension EngineError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .timelineEmpty:
      "The timeline is empty. Add a clip first."
    case .mediaMissing(let id):
      "A clip uses media \(id), which isn't in the project."
    case .mediaUnreadable(let url):
      "\(url.lastPathComponent) couldn't be read for playback."
    case .compositionFailed:
      "The timeline couldn't be prepared for playback."
    case .metalUnavailable:
      "This Mac's GPU couldn't be set up for rendering."
    case .renderFailed:
      "A frame couldn't be rendered."
    case .frameUnavailable(let seconds):
      "There's no frame at \(seconds) seconds. Pick a time inside the timeline."
    case .imageEncodingFailed:
      "The rendered frame couldn't be saved as an image."
    }
  }
}
