import Foundation
import ShadesCore

/// Animates layers with a ready-made move (pop, slide in, float, orbit, scatter, stack), written
/// as ordinary keyframes around where each layer rests now.
public struct ApplyMotion: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipIDs: [Clip.ID],
    preset: MotionPreset,
    at time: MediaTime? = nil,
    duration: MediaTime? = nil,
    edge: Edge? = nil,
    radius: Double? = nil,
  ) {
    self.clipIDs = clipIDs
    self.preset = preset
    at = time
    self.duration = duration
    self.edge = edge
    self.radius = radius
  }

  // MARK: Public

  /// The side a slide comes in from.
  public enum Edge: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom
  }

  public static let title = "Apply Motion"
  public static let name = "apply_motion"
  public static let summary = "Animate layers with a ready-made move, as keyframes around where "
    + "each rests now: pop (springs in from nothing), slideIn (from an edge), float (gentle bob "
    + "for the whole clip), orbit (the clips circle together in a ring), scatter (fly apart and "
    + "fade), stack (land one after another like polaroids). Starts at `at` (default each "
    + "clip's start) and lasts `duration` (default 0.6 s; orbit and float use the whole clip)."
  public static let parameters = JSONSchema.object(
    [
      "clip_ids": Fields.clipIDs,
      "preset": JSONSchema.string("The move", values: MotionPreset.allCases.map(\.rawValue)),
      "at": Fields.time("When it starts"),
      "duration": JSONSchema.number("How long the move takes, in seconds", minimum: 0.05),
      "edge": JSONSchema.string(
        "Where slideIn comes from (default left)",
        values: Edge.allCases.map(\.rawValue),
      ),
      "radius": JSONSchema.number(
        "Orbit ring radius as a fraction of the frame height (default 0.3)",
        minimum: 0.01,
      ),
    ],
    required: ["clip_ids", "preset"],
  )

  public let clipIDs: [Clip.ID]
  public let preset: MotionPreset
  public let at: MediaTime?
  public let duration: MediaTime?
  public let edge: Edge?
  public let radius: Double?

  public func apply(to project: inout Project) throws(CommandError) {
    guard !clipIDs.isEmpty else {
      throw rejected(.invalidValue("give at least one clip"))
    }
    let locations = try clipIDs.map { id throws(CommandError) in try project.requireClip(id) }
    let length = (duration ?? MediaTime(seconds: 0.6)).seconds
    for (index, location) in locations.enumerated() {
      var clip = project.timeline.tracks[location.track].clips[location.clip]
      let start = max(project.onFrame(at ?? clip.timelineStart), clip.timelineStart)
      let moves = keyframes(
        for: clip,
        index: index,
        count: locations.count,
        start: start.seconds,
        length: length,
        aspect: project.timeline.format.aspect,
      )
      for (property, time, value, easing) in moves {
        let moment = min(
          max(project.onFrame(MediaTime(seconds: time)), clip.timelineStart),
          clip.timelineEnd,
        )
        let source = clip.sourceTime(at: moment)
        clip.keyframes.removeAll { $0.property == property && $0.time == source }
        clip.keyframes.append(Keyframe(
          property: property,
          time: source,
          value: value,
          easing: easing,
        ))
      }
      clip.keyframes.sort { $0.time < $1.time }
      project.timeline.tracks[location.track].clips[location.clip] = clip
    }
  }

  // MARK: Private

  /// The keyframes one clip gets: property, timeline seconds, value and easing.
  private func keyframes(
    for clip: Clip,
    index: Int,
    count: Int,
    start: Double,
    length: Double,
    aspect: Double,
  ) -> [(AnimatedProperty, Double, Double, Easing)] {
    let rest = clip.transform(at: MediaTime(seconds: start))
    let end = clip.timelineEnd.seconds
    switch preset {
    case .pop:
      return [
        (.scale, start, 0.01, .bouncy),
        (.scale, start + length, rest.scale, .linear),
        (.opacity, start, 0, .easeOut),
        (.opacity, start + length * 0.3, 1, .linear),
      ]

    case .slideIn:
      let side = edge ?? .left
      let property: AnimatedProperty = side == .left || side == .right ? .x : .y
      let restValue = property == .x ? rest.x : rest.y
      let away = side == .left || side == .top ? -1.2 : 1.2
      return [(property, start, away, .spring), (property, start + length, restValue, .linear)]

    case .float:
      return stride(from: start, through: end, by: 0.8).enumerated().flatMap { step, time in
        let up = step.isMultiple(of: 2) ? -1.0 : 1.0
        let phase = Double(index) * 0.3
        return [
          (AnimatedProperty.y, time + phase, rest.y + up * 0.012, Easing.easeInOut),
          (.rotation, time + phase, rest.rotation + up * 2, .easeInOut),
        ]
      }

    case .orbit:
      let ring = (radius ?? 0.3)
      let turns = max((end - start) / 6, 0.25)
      let steps = Int((turns * 24).rounded(.up))
      return (0 ... steps).flatMap { step -> [(AnimatedProperty, Double, Double, Easing)] in
        let progress = Double(step) / Double(steps)
        let angle = 2 * .pi * (Double(index) / Double(count) + turns * progress)
        let time = start + (end - start) * progress
        return [
          (.x, time, rest.x + ring * sin(angle) / aspect, .linear),
          (.y, time, rest.y - ring * cos(angle), .linear),
        ]
      }

    case .scatter:
      let angle = 2 * .pi * (Double(index) + 0.5) / Double(count)
      return [
        (.x, start, rest.x, .easeIn),
        (.x, start + length, rest.x + 1.4 * sin(angle), .linear),
        (.y, start, rest.y, .easeIn),
        (.y, start + length, rest.y - 1.4 * cos(angle), .linear),
        (.opacity, start, 1, .easeIn),
        (.opacity, start + length, 0, .linear),
      ]

    case .stack:
      let landing = start + Double(index) * length * 0.6
      // why: a fixed spread of tilts per position looks hand-placed and stays the same each time.
      let tilt = [-6.0, 4, -3, 7, -5, 2][index % 6]
      return [
        (.scale, landing, rest.scale * 1.4, .spring),
        (
          .scale,
          landing + length,
          rest.scale,
          .linear,
        ),
        (.opacity, landing, 0, .easeOut),
        (.opacity, landing + length * 0.25, 1, .linear),
        (.rotation, landing, rest.rotation + tilt * 3, .spring),
        (.rotation, landing + length, rest.rotation + tilt, .linear),
      ]
    }
  }

}
