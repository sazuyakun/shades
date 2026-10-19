import Foundation
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
    guard clipID != targetID, let mediaID = target.mediaID else {
      throw rejected(.invalidValue("follow a video clip with another layer"))
    }
    let media = try project.requireMedia(mediaID)
    let start = max(clip.timelineStart, target.timelineStart)
    let end = min(clip.timelineEnd, target.timelineEnd)
    let moments = path
      .map { (time: target.timelineTime(atSource: $0.time), point: $0) }
      .filter { start <= $0.time && $0.time <= end }
    guard let first = moments.first else {
      throw rejected(.invalidRange("the path doesn't cover the time both clips are on screen"))
    }
    let anchor = position(of: first.point, in: target, media: media, at: first.time, project)
    let offsetX = clip.value(of: .x, at: first.time) - anchor.x
    let offsetY = clip.value(of: .y, at: first.time) - anchor.y
    let sources = moments.map { clip.sourceTime(at: project.onFrame($0.time)) }
    clip.keyframes.removeAll { keyframe in
      (keyframe.property == .x || keyframe.property == .y)
        && sources.first.map { $0 <= keyframe.time } == true
        && sources.last.map { keyframe.time <= $0 } == true
    }
    for (moment, source) in zip(moments, sources) {
      let spot = position(of: moment.point, in: target, media: media, at: moment.time, project)
      clip.keyframes.removeAll { $0.time == source && ($0.property == .x || $0.property == .y) }
      clip.keyframes.append(Keyframe(property: .x, time: source, value: spot.x + offsetX))
      clip.keyframes.append(Keyframe(property: .y, time: source, value: spot.y + offsetY))
    }
    clip.keyframes.sort { $0.time < $1.time }
    project.timeline.tracks[location.track].clips[location.clip] = clip
  }

  // MARK: Private

  /// Where a point of the target's picture is in the frame, as clip offsets (fractions of the
  /// frame from its centre), with the target fitted, scaled, rotated and moved as it is then.
  private func position(
    of point: SubjectPoint,
    in target: Clip,
    media: Media,
    at time: MediaTime,
    _ project: Project,
  ) -> (x: Double, y: Double) {
    let frame = project.timeline.format
    let pictureAspect = Double(max(media.width, 1)) / Double(max(media.height, 1))
    let frameAspect = Double(frame.width) / Double(frame.height)
    let fitWidth = pictureAspect > frameAspect ? 1 : pictureAspect / frameAspect
    let fitHeight = pictureAspect > frameAspect ? frameAspect / pictureAspect : 1
    let transform = target.transform(at: time)
    let across = (point.x - 0.5) * fitWidth * transform.scale * Double(frame.width)
    let down = (point.y - 0.5) * fitHeight * transform.scale * Double(frame.height)
    let angle = transform.rotation * .pi / 180
    let turnedAcross = across * cos(angle) - down * sin(angle)
    let turnedDown = across * sin(angle) + down * cos(angle)
    return (
      turnedAcross / Double(frame.width) + transform.x,
      turnedDown / Double(frame.height) + transform.y,
    )
  }

}
