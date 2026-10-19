import CoreGraphics
import ShadesCore
import simd

/// The values the shader needs to draw one layer. Its memory layout must match
/// `FrameUniforms` in Shaders/Layers.metal.
struct FrameUniforms {

  // MARK: Lifecycle

  /// Works out how to draw a stored frame of `stored` size, tagged with `rotation`, into an
  /// output of `output` size: placed by `transform` (in 3D, with perspective), seen through
  /// `camera`, and blended by `opacity`. Pictures are fitted inside the output, unless
  /// `isNaturalSize` (text), which keeps their own pixel size.
  init(
    stored: CGSize,
    rotation: CGAffineTransform,
    output: CGSize,
    transform: ClipTransform = .identity,
    camera: ClipTransform = .identity,
    opacity: Double = 1,
    isNaturalSize: Bool = false,
  ) {
    let upright = CGRect(origin: .zero, size: stored).applying(rotation)
    let uprightToStored = CGAffineTransform(scaleX: upright.width, y: upright.height)
      .translatedBy(x: upright.minX / upright.width, y: upright.minY / upright.height)
      .concatenating(rotation.inverted())
      .concatenating(CGAffineTransform(scaleX: 1 / stored.width, y: 1 / stored.height))
    let uprightAspect = upright.width / upright.height
    let outputAspect = output.width / output.height
    let size = SIMD2(Float(output.width), Float(output.height))
    self.transform = Self.projection(size: size) * Self.view(camera, size: size)
      * Self.model(transform, size: size)
    matrix = SIMD4(
      Float(uprightToStored.a),
      Float(uprightToStored.b),
      Float(uprightToStored.c),
      Float(uprightToStored.d),
    )
    fit =
      if isNaturalSize {
        SIMD2(Float(upright.width / output.width), Float(upright.height / output.height))
      } else if uprightAspect > outputAspect {
        SIMD2(1, Float(outputAspect / uprightAspect))
      } else {
        SIMD2(Float(uprightAspect / outputAspect), 1)
      }
    offset = SIMD2(Float(uprightToStored.tx), Float(uprightToStored.ty))
    frameSize = size
    self.opacity = Float(opacity)
  }

  // MARK: Internal

  /// Takes a corner of the layer (pixels from the frame's centre, y up) to the screen, with
  /// perspective.
  let transform: simd_float4x4
  let matrix: SIMD4<Float>
  let fit: SIMD2<Float>
  let offset: SIMD2<Float>
  let frameSize: SIMD2<Float>
  let opacity: Float

  // MARK: Private

  /// How far the viewer sits from the frame, in frame heights: about a 28° vertical view, a
  /// gentle perspective.
  private static let viewingDistance: Float = 2

  /// Places a layer in the world (pixels, y up, z towards the viewer): scaled, turned, tilted,
  /// rotated, then moved.
  private static func model(_ transform: ClipTransform, size: SIMD2<Float>) -> simd_float4x4 {
    translation(
      Float(transform.x) * size.x,
      -Float(transform.y) * size.y,
      Float(transform.depth) * size.y,
    )
      * rotationZ(-radians(transform.rotation))
      * rotationX(-radians(transform.tiltX))
      * rotationY(radians(transform.tiltY))
      * scaling(Float(transform.scale))
  }

  /// The world as the camera sees it after its move: panning right shifts the world left,
  /// zooming in grows it, moving closer brings it nearer.
  private static func view(_ camera: ClipTransform, size: SIMD2<Float>) -> simd_float4x4 {
    scaling(Float(camera.scale))
      * rotationZ(radians(camera.rotation))
      * rotationX(radians(camera.tiltX))
      * rotationY(-radians(camera.tiltY))
      * translation(
        -Float(camera.x) * size.x,
        Float(camera.y) * size.y,
        Float(camera.depth) * size.y,
      )
  }

  /// Perspective onto the screen: things nearer the viewer look bigger.
  private static func projection(size: SIMD2<Float>) -> simd_float4x4 {
    let distance = viewingDistance * size.y
    return simd_float4x4(columns: (
      SIMD4(2 / size.x, 0, 0, 0),
      SIMD4(0, 2 / size.y, 0, 0),
      SIMD4(0, 0, 0, -1 / distance),
      SIMD4(0, 0, 0, 1),
    ))
  }

  private static func radians(_ degrees: Double) -> Float {
    Float(degrees * .pi / 180)
  }

  private static func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
    simd_float4x4(columns: (
      SIMD4(1, 0, 0, 0),
      SIMD4(0, 1, 0, 0),
      SIMD4(0, 0, 1, 0),
      SIMD4(x, y, z, 1),
    ))
  }

  private static func scaling(_ factor: Float) -> simd_float4x4 {
    simd_float4x4(diagonal: SIMD4(factor, factor, factor, 1))
  }

  private static func rotationX(_ angle: Float) -> simd_float4x4 {
    simd_float4x4(columns: (
      SIMD4(1, 0, 0, 0),
      SIMD4(0, cos(angle), sin(angle), 0),
      SIMD4(0, -sin(angle), cos(angle), 0),
      SIMD4(0, 0, 0, 1),
    ))
  }

  private static func rotationY(_ angle: Float) -> simd_float4x4 {
    simd_float4x4(columns: (
      SIMD4(cos(angle), 0, -sin(angle), 0),
      SIMD4(0, 1, 0, 0),
      SIMD4(sin(angle), 0, cos(angle), 0),
      SIMD4(0, 0, 0, 1),
    ))
  }

  private static func rotationZ(_ angle: Float) -> simd_float4x4 {
    simd_float4x4(columns: (
      SIMD4(cos(angle), sin(angle), 0, 0),
      SIMD4(-sin(angle), cos(angle), 0, 0),
      SIMD4(0, 0, 1, 0),
      SIMD4(0, 0, 0, 1),
    ))
  }

}
