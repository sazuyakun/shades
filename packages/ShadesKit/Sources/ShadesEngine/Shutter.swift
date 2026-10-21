import CoreGraphics
import ShadesCore
import simd

/// The maths of motion blur on moving layers: the moments a frame's shutter is open, and how
/// many of them a layer must be drawn at so its blur looks smooth rather than stepped.
enum Shutter {

  // MARK: Internal

  /// The farthest, in pixels, a layer may jump between two drawn moments before the steps show.
  static let step = 1.5

  /// The layer's poses at the moments the shutter is open: `length` seconds centred on `time`,
  /// enough of them (up to `limit`) that it never jumps more than `step` pixels in a `size`
  /// frame. Empty when it barely moves, so it's drawn once, sharp. `place` gives its pose at
  /// any moment.
  static func poses(
    around time: MediaTime,
    length: Double,
    size: CGSize,
    limit: Int,
    place: (MediaTime) -> LayerPose,
  ) -> [LayerPose] {
    guard length > 0, limit > 1 else {
      return []
    }
    let open = place(time - moment(length / 2))
    let middle = place(time)
    let close = place(time + moment(length / 2))
    let travel = distance(from: open, to: middle, size: size)
      + distance(from: middle, to: close, size: size)
    let count = min(Int((travel / step).rounded()), limit)
    guard count > 1 else {
      return []
    }
    return (0 ..< count).map { index in
      let share = Double(index) / Double(count - 1) - 0.5
      return place(time + moment(length * share))
    }
  }

  // MARK: Private

  /// A timescale fine enough for many moments inside even a short shutter (the timeline's 600
  /// would round them together), and a multiple of it so sums stay exact.
  private static let timescale: Int32 = 48000

  private static func moment(_ seconds: Double) -> MediaTime {
    MediaTime(seconds: seconds, timescale: timescale)
  }

  /// How far, in pixels, the farthest-moving corner of a frame-sized layer goes between two
  /// poses. The frame stands in for the layer: exact for moves, generous for small layers that
  /// turn or grow.
  private static func distance(from start: LayerPose, to end: LayerPose, size: CGSize) -> Double {
    let from = corners(at: start, size: size)
    let to = corners(at: end, size: size)
    return zip(from, to).lazy.map { Double(simd_distance($0, $1)) }.max() ?? 0
  }

  /// Where a frame-sized layer's corners land on screen, in pixels.
  private static func corners(at pose: LayerPose, size: CGSize) -> [SIMD2<Float>] {
    let matrix = FrameUniforms(
      stored: size,
      rotation: .identity,
      output: size,
      transform: pose.transform,
      camera: pose.camera,
    ).transform
    let half = SIMD2(Float(size.width), Float(size.height)) / 2
    return [SIMD2<Float>(-1, -1), SIMD2(1, -1), SIMD2(-1, 1), SIMD2(1, 1)].map { corner in
      let projected = matrix * SIMD4(corner.x * half.x, corner.y * half.y, 0, 1)
      return SIMD2(projected.x, projected.y) / projected.w * half
    }
  }

}
