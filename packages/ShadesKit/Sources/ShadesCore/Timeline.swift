import Foundation

// MARK: - Timeline

/// An edit made of tracks, shown to the user as a "sequence" (`Sequence` is taken by Swift).
/// Tracks are ordered bottom to top within each kind: the first video track is V1, drawn under
/// V2.
public struct Timeline: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    name: String = "Main",
    format: VideoFormat = .standard,
    tracks: [Track] = [Track(kind: .video), Track(kind: .audio)],
    markers: [Marker] = [],
    camera: [Keyframe] = [],
    gain: Double = 1,
  ) {
    self.name = name
    self.format = format
    self.tracks = tracks
    self.markers = markers
    self.camera = camera
    self.gain = gain
  }

  // MARK: Public

  public var name: String
  /// The size and frame rate this edit plays and exports at, whatever its clips' sizes.
  public var format: VideoFormat
  public var tracks: [Track]
  public var markers: [Marker]
  /// The camera's moves (zoom as scale, pan as x and y, rotation and tilt), in timeline time.
  /// Without keyframes it rests: no zoom, no pan.
  public var camera: [Keyframe]
  /// The whole mix's level (1 unchanged), set by loudness normalising.
  public var gain: Double

  /// The length of the whole edit.
  public var duration: MediaTime {
    tracks.map(\.end).max() ?? .zero
  }

  /// Every clip on every track.
  public var allClips: [Clip] {
    tracks.flatMap(\.clips)
  }

  /// Where the camera is at `time`.
  public func camera(at time: MediaTime) -> ClipTransform {
    camera.transform(at: time, fixed: .identity)
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

// MARK: Codable

extension Timeline: Codable {

  // MARK: Lifecycle

  /// Reads a timeline, including ones saved before the camera existed.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      name: container.decode(String.self, forKey: .name),
      format: container.decode(VideoFormat.self, forKey: .format),
      tracks: container.decode([Track].self, forKey: .tracks),
      markers: container.decode([Marker].self, forKey: .markers),
      camera: container.decodeIfPresent([Keyframe].self, forKey: .camera) ?? [],
      gain: container.decodeIfPresent(Double.self, forKey: .gain) ?? 1,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case name
    case format
    case tracks
    case markers
    case camera
    case gain
  }

}
