import Foundation

/// Where the user was in a project, so reopening puts them back: playhead and selection.
public struct Session: Codable, Hashable, Sendable {
  public init(playhead: Double = 0, selection: [UUID] = []) {
    self.playhead = playhead
    self.selection = selection
  }

  public var playhead: Double
  public var selection: [UUID]
}
