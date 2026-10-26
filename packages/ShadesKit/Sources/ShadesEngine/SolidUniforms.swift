import CoreGraphics
import ShadesCore
import simd

/// What the shader needs to stack and light solid 3D letters. Its memory layout must match
/// `Solid` in Shaders/Layers.metal.
struct SolidUniforms {

  // MARK: Lifecycle

  /// The letters of `solid`, drawn from a `picture`-sized picture, placed by `transform` and seen
  /// through `camera` in an `output`-sized frame.
  init(
    _ solid: SolidText,
    picture: CGSize,
    transform: ClipTransform,
    camera: ClipTransform,
    output: CGSize,
  ) {
    let size = SIMD2(Float(output.width), Float(output.height))
    turn = FrameUniforms.view(camera, size: size) * FrameUniforms.model(transform, size: size)
    depth = Float(solid.depth)
    bevel = Float(min(solid.bevel, solid.depth))
    // why: slices only need to be close on screen, so letters seen nearly head-on, whose depth
    // looks short, need few.
    let corners = Self.screenCorners(
      solid,
      picture: picture,
      transform: transform,
      camera: camera,
      output: output,
    )
    let looksDeep = zip(corners.front, corners.back).lazy.map { simd_distance($0, $1) }.max() ?? 0
    slices = Int32(min(max(Int(Double(looksDeep) / Self.sliceSpacing) + 2, 2), Self.maxSlices))
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
  /// Copies of the letters stacked through the depth.
  let slices: Int32
  /// 1 when the front faces the viewer, so slices are drawn from the back forward.
  let backFirst: Int32

  /// Where the corners of the letters' front and back land in the frame, in pixels from its
  /// centre (y up).
  static func screenCorners(
    _ solid: SolidText,
    picture: CGSize,
    transform: ClipTransform,
    camera: ClipTransform,
    output: CGSize,
  ) -> (front: [SIMD2<Float>], back: [SIMD2<Float>]) {
    let matrix = FrameUniforms(
      stored: picture,
      rotation: .identity,
      output: output,
      transform: transform,
      camera: camera,
      isNaturalSize: true,
    ).transform
    let half = SIMD2(Float(output.width), Float(output.height)) / 2
    let project = { (z: Float) in
      [SIMD2<Float>(-1, -1), SIMD2(1, -1), SIMD2(-1, 1), SIMD2(1, 1)].map { corner in
        let point = matrix * SIMD4(
          corner.x * Float(picture.width) / 2,
          corner.y * Float(picture.height) / 2,
          z,
          1,
        )
        return SIMD2(point.x, point.y) / point.w * half
      }
    }
    return (project(0), project(-Float(solid.depth)))
  }

  // MARK: Private

  /// Pixels apart the slices land on screen: close enough that the sides look solid.
  private static let sliceSpacing = 2.0

  /// Slices at most, so very deep letters stay quick to draw.
  private static let maxSlices = 96

}
