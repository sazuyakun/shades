import ShadesCore

/// Makes a layer follow something moving in a video clip: x and y keyframes along a path through
/// that clip's picture, keeping the layer where it sits now relative to the thing.
public struct FollowPath: Command {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, targetID: Clip.ID, path: [SubjectPoint]) {
    self.clipID = clipID
    self.targetID = targetID
    self.path = path
  }

  // MARK: Public

  public static let title = "Follow"

  public let clipID: Clip.ID
  public let targetID: Clip.ID
  /// Where the thing is, in the target's source time and picture.
  public let path: [SubjectPoint]

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    var clip = project.timeline.tracks[location.track].clips[location.clip]
    let targetLocation = try project.requireClip(targetID)
    let target = project.timeline.tracks[targetLocation.track].clips[targetLocation.clip]
    guard
      clipID != targetID, target.mediaID != nil,
      let aspect = project.pictureAspect(of: target)
    else {
      throw rejected(.invalidValue("follow a video clip with another layer"))
    }
    func position(of point: SubjectPoint, at time: MediaTime) -> (x: Double, y: Double) {
      project.frameOffset(of: (point.x, point.y), in: target, pictureAspect: aspect, at: time)
    }
    let start = max(clip.timelineStart, target.timelineStart)
    let end = min(clip.timelineEnd, target.timelineEnd)
    let moments = path
      .map { (time: target.timelineTime(atSource: $0.time), point: $0) }
      .filter { start <= $0.time && $0.time <= end }
    guard let first = moments.first else {
      throw rejected(.invalidRange("the path doesn't cover the time both clips are on screen"))
    }
    let anchor = position(of: first.point, at: first.time)
    let offsetX = clip.value(of: .x, at: first.time) - anchor.x
    let offsetY = clip.value(of: .y, at: first.time) - anchor.y
    let sources = moments.map { clip.sourceTime(at: project.onFrame($0.time)) }
    clip.keyframes.removeAll { keyframe in
      (keyframe.property == .x || keyframe.property == .y)
        && sources.first.map { $0 <= keyframe.time } == true
        && sources.last.map { keyframe.time <= $0 } == true
    }
    for (moment, source) in zip(moments, sources) {
      let spot = position(of: moment.point, at: moment.time)
      clip.keyframes.removeAll { $0.time == source && ($0.property == .x || $0.property == .y) }
      clip.keyframes.append(Keyframe(property: .x, time: source, value: spot.x + offsetX))
      clip.keyframes.append(Keyframe(property: .y, time: source, value: spot.y + offsetY))
    }
    clip.keyframes.sort { $0.time < $1.time }
    project.timeline.tracks[location.track].clips[location.clip] = clip
  }

}
