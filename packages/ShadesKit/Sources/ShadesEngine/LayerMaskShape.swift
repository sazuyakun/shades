import ShadesCore

/// One layer mask as the shader reads it, placed for this frame. Its memory layout must match
/// `LayerMaskShape` in Shaders/Layers.metal.
struct LayerMaskShape {

  // MARK: Lifecycle

  private init(_ mask: LayerMask, firstPoint: Int) {
    x = Float(mask.x)
    y = Float(mask.y)
    width = Float(mask.width)
    height = Float(mask.height)
    feather = Float(mask.feather)
    expansion = Float(mask.expansion)
    opacity = Float(mask.opacity)
    kind =
      switch mask.shape {
      case .rectangle: 0
      case .ellipse: 1
      case .path: 2
      }
    inverted = mask.inverted ? 1 : 0
    subtracts = mask.mode == .subtract ? 1 : 0
    self.firstPoint = Int32(firstPoint)
    pointCount = mask.shape == .path ? Int32(mask.points.count) : 0
  }

  // MARK: Internal

  let x: Float
  let y: Float
  let width: Float
  let height: Float
  let feather: Float
  let expansion: Float
  let opacity: Float
  let kind: Int32
  let inverted: Int32
  let subtracts: Int32
  let firstPoint: Int32
  let pointCount: Int32

  /// The masks' shapes, and all their path outlines' points one after another. A path with too
  /// few points to enclose anything is left out.
  static func shapes(of masks: [LayerMask]) -> (shapes: [LayerMaskShape], points: [SIMD2<Float>]) {
    var shapes = [LayerMaskShape]()
    var points = [SIMD2<Float>]()
    for mask in masks where mask.shape != .path || mask.points.count >= 3 {
      shapes.append(LayerMaskShape(mask, firstPoint: points.count))
      if mask.shape == .path {
        points += mask.points.map { SIMD2(Float($0.x), Float($0.y)) }
      }
    }
    return (shapes, points)
  }

}
