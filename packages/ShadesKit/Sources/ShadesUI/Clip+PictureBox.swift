import CoreGraphics
import Foundation
import ShadesCore

extension Clip {

  // MARK: Internal

  /// Where a box drawn over the frame (fractions from its top left) falls in the clip's own
  /// picture at `time`, undoing how the picture is fitted, scaled, turned and moved. The part
  /// outside the picture is cut off.
  func pictureBox(
    _ box: CGRect,
    media: Media,
    format: VideoFormat,
    at time: MediaTime,
  ) -> CGRect {
    let corners = [
      picturePoint(x: box.minX, y: box.minY, media: media, format: format, at: time),
      picturePoint(x: box.maxX, y: box.maxY, media: media, format: format, at: time),
    ]
    return CGRect(
      x: min(corners[0].x, corners[1].x),
      y: min(corners[0].y, corners[1].y),
      width: abs(corners[1].x - corners[0].x),
      height: abs(corners[1].y - corners[0].y),
    ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
  }

  // MARK: Private

  /// The spot of the clip's picture (fractions from its top left) under a spot of the frame.
  private func picturePoint(
    x: Double,
    y: Double,
    media: Media,
    format: VideoFormat,
    at time: MediaTime,
  ) -> CGPoint {
    let width = Double(format.width)
    let height = Double(format.height)
    let pictureAspect = Double(max(media.width, 1)) / Double(max(media.height, 1))
    let frameAspect = width / height
    let fitWidth = pictureAspect > frameAspect ? 1 : pictureAspect / frameAspect
    let fitHeight = pictureAspect > frameAspect ? frameAspect / pictureAspect : 1
    let placement = transform(at: time)
    let turnedAcross = (x - 0.5 - placement.x) * width
    let turnedDown = (y - 0.5 - placement.y) * height
    let angle = placement.rotation * .pi / 180
    let across = turnedAcross * cos(angle) + turnedDown * sin(angle)
    let down = -turnedAcross * sin(angle) + turnedDown * cos(angle)
    return CGPoint(
      x: across / (fitWidth * placement.scale * width) + 0.5,
      y: down / (fitHeight * placement.scale * height) + 0.5,
    )
  }

}
