import IOSurface

/// What draws a text clip as solid 3D letters: how far each pixel is from its letters' edge, and
/// how deep and bevelled they are, in pixels of the frame.
struct SolidText: Sendable {
  /// The letters' distance field (`DistanceField`), one byte a pixel.
  let distance: IOSurface
  /// Pixels per step of the distance field.
  let unit: Double
  let depth: Double
  let bevel: Double
}
