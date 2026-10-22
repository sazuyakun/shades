import CoreGraphics
import ShadesCore
import simd

/// What the shader needs to stack and light solid 3D letters. Its memory layout must match
/// `Solid` in Shaders/Layers.metal.
struct SolidUniforms {

  // MARK: Lifecycle

  /// The letters of `solid` placed by `transform` and seen through `camera` in an `output`-sized
  /// frame.
  init(_ solid: SolidText, transform: ClipTransform, camera: ClipTransform, output: CGSize) {
    let size = SIMD2(Float(output.width), Float(output.height))
    turn = FrameUniforms.view(camera, size: size) * FrameUniforms.model(transform, size: size)
    depth = Float(solid.depth)
    bevel = Float(min(solid.bevel, solid.depth))
    unit = Float(solid.unit)
    slices = Int32(min(max(Int(solid.depth / Self.sliceSpacing) + 2, 2), Self.maxSlices))
    let center = turn * SIMD4(0, 0, 0, 1)
    let front = turn * SIMD4(0, 0, 1, 0)
    let viewer = SIMD3(0, 0, FrameUniforms.viewingDistance * size.y)
    let toViewer = viewer - SIMD3(center.x, center.y, center.z)
    backFirst = simd_dot(SIMD3(front.x, front.y, front.z), toViewer) > 0 ? 1 : 0
  }

  // MARK: Internal

  /// The layer's own turn and the camera's: which way its faces point in the world.
  let turn: simd_float4x4
  let depth: Float
  let bevel: Float
  let unit: Float
  /// Copies of the letters stacked through the depth.
  let slices: Int32
  /// 1 when the front faces the viewer, so slices are drawn from the back forward.
  let backFirst: Int32

  // MARK: Private

  /// Pixels between slices: close enough that the sides look solid when turned.
  private static let sliceSpacing = 1.5

  /// Slices at most, so very deep letters stay quick to draw.
  private static let maxSlices = 96

}
