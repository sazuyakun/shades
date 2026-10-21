import Foundation
import ShadesCore

/// Reframes a clip to fill the 4:3 frame and pans with its subject like a calm camera operator:
/// x / y keyframes along the subject's path, steadied (small moves are ignored), held to a top
/// speed and eased, never so far that an edge shows.
public struct PanToSubject: Command {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, path: [SubjectPoint]) {
    self.clipID = clipID
    self.path = path
  }

  // MARK: Public

  public static let title = ReframeClip.title
  /// How far (a fraction of the frame) the subject can drift before the camera moves.
  public static let deadZone = 0.03
  /// The fastest the camera pans, in frame widths (or heights) per second.
  public static let topSpeed = 0.1
  /// How long the camera takes to ease into and out of a move, in seconds.
  public static let easing = 2.0

  public let clipID: Clip.ID
  /// Where the subject is, in the clip's source time and picture.
  public let path: [SubjectPoint]

  public func apply(to project: inout Project) throws(CommandError) {
    let framing = try Framing(of: clipID, in: project)
    var clip = framing.clip
    let start = clip.sourceStart
    let end = clip.sourceEnd
    let inside = path.filter { start <= $0.time && $0.time <= end }.sorted { $0.time < $1.time }
    guard inside.count > 1 else {
      throw rejected(.invalidValue("the subject's path doesn't cover this clip; cut it out first"))
    }
    clip.transform = ClipTransform(scale: framing.scale)
    clip.keyframes.removeAll { $0.property == .x || $0.property == .y }
    for (axis, position) in [(AnimatedProperty.x, \SubjectPoint.x), (.y, \.y)] {
      let targets = inside.map { point in
        (
          time: point.time.seconds,
          value: framing.offset(forSubjectAt: point[keyPath: position], axis: axis),
        )
      }
      guard targets.contains(where: { $0.value != 0 }) else {
        continue
      }
      clip.keyframes += Self.camera(following: targets).map { move in
        Keyframe(property: axis, time: MediaTime(seconds: move.time), value: move.value)
      }
    }
    clip.keyframes.sort { $0.time < $1.time }
    project.timeline.tracks[framing.location.track].clips[framing.location.clip] = clip
  }

  // MARK: Internal

  /// Camera positions following `targets` (time in seconds, offset): steadied, speed-limited,
  /// eased, then thinned to the fewest points that keep the move.
  static func camera(following targets: [(time: Double, value: Double)])
    -> [(time: Double, value: Double)]
  {
    guard var camera = targets.first?.value else {
      return []
    }
    var moves = targets.map { target in
      camera = min(max(camera, target.value - deadZone), target.value + deadZone)
      return (time: target.time, value: camera)
    }
    for index in moves.indices.dropFirst() {
      moves[index].value = limited(moves[index], from: moves[index - 1])
    }
    for index in moves.indices.dropLast().reversed() {
      moves[index].value = limited(moves[index], from: moves[index + 1])
    }
    let eased = moves.map { move in
      let near = moves.filter { abs($0.time - move.time) <= easing / 2 }
      return (time: move.time, value: near.map(\.value).reduce(0, +) / Double(near.count))
    }
    return thinned(eased)
  }

  // MARK: Private

  /// How far a thinned path may stray from the eased one, as a fraction of the frame.
  private static let tolerance = 0.002

  /// `move`'s value, brought within top speed of `neighbour`.
  private static func limited(
    _ move: (time: Double, value: Double),
    from neighbour: (time: Double, value: Double),
  ) -> Double {
    let step = topSpeed * abs(move.time - neighbour.time)
    return min(max(move.value, neighbour.value - step), neighbour.value + step)
  }

  /// The fewest points whose straight lines stay within `tolerance` of `points`
  /// (Ramer–Douglas–Peucker).
  private static func thinned(_ points: [(time: Double, value: Double)])
    -> [(time: Double, value: Double)]
  {
    guard let first = points.first, let last = points.last, points.count > 2 else {
      return points
    }
    let span = last.time - first.time
    let strays = points.indices.dropFirst().dropLast().map { index in
      let fraction = span > 0 ? (points[index].time - first.time) / span : 0
      return abs(points[index].value - (first.value + (last.value - first.value) * fraction))
    }
    guard let worst = strays.max(), worst > tolerance, let split = strays.firstIndex(of: worst)
    else {
      return [first, last]
    }
    let middle = split + 1
    return thinned(Array(points[...middle])).dropLast() + thinned(Array(points[middle...]))
  }

}
