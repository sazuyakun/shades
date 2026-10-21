import Foundation
import ShadesCore

extension Project {

  // MARK: Public

  /// The shape of `clip`'s upright picture (width over height): its media's, or the frame's for
  /// drawings and adjustment clips. `nil` for text, whose size comes from its words.
  public func pictureAspect(of clip: Clip) -> Double? {
    switch clip.source {
    case .media(let id):
      media(withID: id).map { Double(max($0.width, 1)) / Double(max($0.height, 1)) }
    case .drawing,
         .adjustment:
      Double(timeline.format.width) / Double(timeline.format.height)
    case .text:
      nil
    }
  }

  /// Where `point` of a clip's upright picture (fractions from its top left) shows in the frame
  /// at `time`, as offsets from the frame's centre in fractions of the frame: the picture fitted,
  /// scaled, turned and moved as the clip is then (tilt and the camera aside).
  public func frameOffset(
    of point: (x: Double, y: Double),
    in clip: Clip,
    pictureAspect: Double,
    at time: MediaTime,
  ) -> (x: Double, y: Double) {
    let transform = clip.transform(at: time)
    let size = fittedSize(pictureAspect: pictureAspect, scale: transform.scale)
    let across = (point.x - 0.5) * size.width
    let down = (point.y - 0.5) * size.height
    let angle = transform.rotation * .pi / 180
    return (
      (across * cos(angle) - down * sin(angle)) / Double(timeline.format.width) + transform.x,
      (across * sin(angle) + down * cos(angle)) / Double(timeline.format.height) + transform.y,
    )
  }

  /// The point of a clip's upright picture (fractions from its top left) that shows at `offset`
  /// from the frame's centre at `time`: the reverse of `frameOffset`.
  public func picturePoint(
    at offset: (x: Double, y: Double),
    in clip: Clip,
    pictureAspect: Double,
    at time: MediaTime,
  ) -> (x: Double, y: Double) {
    let transform = clip.transform(at: time)
    let size = fittedSize(pictureAspect: pictureAspect, scale: transform.scale)
    let across = (offset.x - transform.x) * Double(timeline.format.width)
    let down = (offset.y - transform.y) * Double(timeline.format.height)
    let angle = -transform.rotation * .pi / 180
    return (
      (across * cos(angle) - down * sin(angle)) / size.width + 0.5,
      (across * sin(angle) + down * cos(angle)) / size.height + 0.5,
    )
  }

  // MARK: Private

  /// The size in pixels of a picture of `pictureAspect` fitted inside the frame, then scaled.
  private func fittedSize(
    pictureAspect: Double,
    scale: Double,
  ) -> (width: Double, height: Double) {
    let frame = timeline.format
    let frameAspect = Double(frame.width) / Double(frame.height)
    let fitWidth = pictureAspect > frameAspect ? 1 : pictureAspect / frameAspect
    let fitHeight = pictureAspect > frameAspect ? frameAspect / pictureAspect : 1
    return (fitWidth * scale * Double(frame.width), fitHeight * scale * Double(frame.height))
  }

}
