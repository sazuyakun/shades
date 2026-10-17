import Foundation

/// An edit made of tracks, shown to the user as a "sequence" (`Sequence` is taken by Swift).
/// Tracks are ordered bottom to top within each kind: the first video track is V1, drawn under
/// V2.
public struct Timeline: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    name: String = "Main",
    format: VideoFormat = .standard,
    tracks: [Track] = [Track(kind: .video), Track(kind: .audio)],
    markers: [Marker] = [],
  ) {
    self.name = name
    self.format = format
    self.tracks = tracks
    self.markers = markers
  }

  // MARK: Public

  public var name: String
  /// The size and frame rate this edit plays and exports at, whatever its clips' sizes.
  public var format: VideoFormat
  public var tracks: [Track]
  public var markers: [Marker]

  /// The length of the whole edit.
  public var duration: MediaTime {
    tracks.map(\.end).max() ?? .zero
  }

  /// Every clip on every track.
  public var allClips: [Clip] {
    tracks.flatMap(\.clips)
  }

  /// The track's short name, like "V1" or "A2".
  public func label(of track: Track) -> String {
    let sameKind = tracks.filter { $0.kind == track.kind }
    let number = (sameKind.firstIndex { $0.id == track.id } ?? 0) + 1
    let letter =
      switch track.kind {
      case .video: "V"
      case .audio: "A"
      case .text: "T"
      }
    return letter + "\(number)"
  }

  /// Where a clip is: its track's index and its own index in that track.
  public func location(ofClip id: Clip.ID) -> (track: Int, clip: Int)? {
    for (trackIndex, track) in tracks.enumerated() {
      if let clipIndex = track.clips.firstIndex(where: { $0.id == id }) {
        return (trackIndex, clipIndex)
      }
    }
    return nil
  }

  /// Looks up a clip anywhere on the timeline.
  public func clip(withID id: Clip.ID) -> Clip? {
    location(ofClip: id).map { tracks[$0.track].clips[$0.clip] }
  }

}
