import ShadesCore

// MARK: - FollowShape

/// Makes one of a clip's masks, or its grade window, follow something moving in the clip's own
/// picture: keyframes along a path, keeping where the shape sits now relative to the thing.
public struct FollowShape: Command {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, shape: Target, path: [SubjectPoint]) {
    self.clipID = clipID
    self.shape = shape
    self.path = path
  }

  // MARK: Public

  /// Which shape of the clip follows.
  public enum Target: Equatable, Sendable {
    /// A mask, by its place in the clip's masks.
    case mask(Int)
    /// The window its grade is limited to.
    case window
  }

  public static let title = "Follow"

  public let clipID: Clip.ID
  public let shape: Target
  /// Where the thing is, in the clip's source time and picture.
  public let path: [SubjectPoint]

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    var clip = project.timeline.tracks[location.track].clips[location.clip]
    guard clip.mediaID != nil, let aspect = project.pictureAspect(of: clip) else {
      throw rejected(.invalidValue("only a video clip's own shapes can follow what moves in it"))
    }
    let points = path.filter { clip.sourceStart <= $0.time && $0.time <= clip.sourceEnd }
    guard let first = points.first, let last = points.last else {
      throw rejected(.invalidRange("the path doesn't cover the time the clip is on screen"))
    }
    let original = clip
    let unchanged = project
    let place = { (point: SubjectPoint) -> (x: Double, y: Double) in
      // why: masks sit on the picture itself; a window sits on the frame, where the picture is.
      guard shape == .window else {
        return (point.x, point.y)
      }
      let offset = unchanged.frameOffset(
        of: (point.x, point.y),
        in: original,
        pictureAspect: aspect,
        at: original.timelineTime(atSource: point.time),
      )
      return (offset.x + 0.5, offset.y + 0.5)
    }
    /// The shape's keyframes with its position along the path, its size and outline kept.
    func following(
      _ keys: [ShapeKeyframe],
      keyframe: (MediaTime) -> ShapeKeyframe,
    ) -> [ShapeKeyframe] {
      let start = keyframe(first.time)
      let anchor = place(first)
      var followed = keys.filter { $0.time < first.time || last.time < $0.time }
      for point in points {
        var key = keyframe(point.time)
        let spot = place(point)
        key.x = spot.x + start.x - anchor.x
        key.y = spot.y + start.y - anchor.y
        followed.set(key)
      }
      return followed
    }
    switch shape {
    case .mask(let index):
      guard clip.masks.indices.contains(index) else {
        throw rejected(.invalidValue("the clip has no mask \(index)"))
      }
      let mask = clip.masks[index]
      clip.masks[index].keyframes = following(mask.keyframes) { mask.keyframe(at: $0) }

    case .window:
      guard let window = clip.grade?.window else {
        throw rejected(.invalidValue("the clip's grade has no window; add one with set_window"))
      }
      clip.grade?.window?.keyframes = following(window.keyframes) { window.keyframe(at: $0) }
    }
    try project.replaceClip(at: location, with: clip)
  }

}
