import Foundation
import ShadesCore

// MARK: - CommandError

/// Why a command couldn't be applied.
public enum CommandError: Error, Equatable {
  case mediaAlreadyAdded(Media.ID)
  case mediaNotFound(Media.ID)
  case clipNotFound(Clip.ID)
  case markerNotFound(Marker.ID)
  case trackNotFound(String)
  case wrongTrackKind(track: String, needs: TrackKind)
  case lastVideoTrack
  case invalidRange(String)
  case invalidValue(String)
  case noRoom(String)
  case noAudio(Clip.ID)
  case cannotJoin(String)
  case unknownTool(String)
  case invalidArguments(String)
  case invalidJSON
  case nothingToUndo
  case nothingToRedo
}

// MARK: LocalizedError

extension CommandError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .mediaAlreadyAdded:
      "This media is already in the project."

    case .mediaNotFound(let id):
      "No media with ID \(id) is in the project. Import it first, or check get_project."

    case .clipNotFound(let id):
      "No clip with ID \(id) is on the timeline. Check get_project for current clip IDs."

    case .markerNotFound(let id):
      "No marker with ID \(id) is on the timeline."

    case .trackNotFound(let label):
      "The timeline has no track \(label). Tracks are named V1, V2… and A1, A2…"

    case .wrongTrackKind(let track, let needs):
      needs == .audio
        ? "\(track) is a video track. Put sound-only media on an audio track (A1, A2…)."
        : "\(track) is an audio track. Put video on a video track (V1, V2…)."

    case .lastVideoTrack:
      "A timeline needs at least one video track."

    case .invalidRange(let reason):
      "That range doesn't work: \(reason)."

    case .invalidValue(let reason):
      "That value doesn't work: \(reason)."

    case .noRoom(let reason):
      "There's no room: \(reason)."

    case .noAudio:
      "This clip has no sound of its own to detach."

    case .cannotJoin(let reason):
      "These clips can't be joined: \(reason)."

    case .unknownTool(let name):
      "There's no tool named \(name)."

    case .invalidArguments(let reason):
      "The arguments are wrong: \(reason)."

    case .invalidJSON:
      "That isn't valid JSON."

    case .nothingToUndo:
      "There's nothing to undo."

    case .nothingToRedo:
      "There's nothing to redo."
    }
  }
}
