import ShadesCommands
import ShadesCore

/// Lowers a music track while someone speaks: volume keyframes on its clips that dip under
/// `speech` and come back up between. Replaces the clips' earlier volume keyframes.
public struct DuckMusic: Command {

  // MARK: Lifecycle

  public init(
    track: Int,
    speech: [TimeRange],
    duckTo: Double = 0.25,
    attack: Double = 0.15,
    release: Double = 0.6,
  ) {
    self.track = track
    self.speech = speech
    self.duckTo = duckTo
    self.attack = attack
    self.release = release
  }

  // MARK: Public

  public static let title = "Duck Music"

  public let track: Int
  /// When someone speaks, in timeline time.
  public let speech: [TimeRange]
  /// The music's level while ducked, as a share of its own (0.25 is about 12 dB down).
  public let duckTo: Double
  /// Seconds the music takes to dip before speech starts.
  public let attack: Double
  /// Seconds the music takes to come back after speech ends.
  public let release: Double

  public func apply(to project: inout Project) throws(CommandError) {
    guard project.timeline.tracks.indices.contains(track) else {
      throw .invalidArguments("there's no music track to duck")
    }
    guard (0 ... 1).contains(duckTo) else {
      throw .invalidValue("the ducked level goes from 0 to 1")
    }
    for index in project.timeline.tracks[track].clips.indices {
      var clip = project.timeline.tracks[track].clips[index]
      let points = DuckingPlanner.envelope(
        speech: speech,
        from: clip.timelineStart,
        to: clip.timelineEnd,
        duckTo: duckTo,
        attack: attack,
        release: release,
      )
      clip.keyframes.removeAll { $0.property == .volume }
      clip.keyframes += points.map { point in
        Keyframe(
          property: .volume,
          time: clip.sourceTime(at: point.time),
          value: clip.volume * point.gain,
        )
      }
      clip.keyframes.sort { $0.time < $1.time }
      project.timeline.tracks[track].clips[index] = clip
    }
  }

}
