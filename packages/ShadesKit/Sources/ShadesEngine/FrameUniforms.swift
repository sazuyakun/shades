import CoreGraphics
import ShadesCore

/// The values the shader needs to draw one layer. Its memory layout must match
/// `FrameUniforms` in Shaders/Layers.metal.
struct FrameUniforms {

  // MARK: Lifecycle

  /// Works out how to draw a stored frame of `stored` size, tagged with `rotation`, into an
  /// output of `output` size, placed by `transform` and blended by `opacity`. Pictures are fitted
  /// inside the output, unless `isNaturalSize` (text), which keeps their own pixel size.
  init(
    stored: CGSize,
    rotation: CGAffineTransform,
    output: CGSize,
    transform: ClipTransform = .identity,
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
    frameSize = SIMD2(Float(output.width), Float(output.height))
    position = SIMD2(Float(transform.x), Float(transform.y))
    scale = Float(transform.scale)
    self.rotation = Float(transform.rotation * .pi / 180)
    self.opacity = Float(opacity)
  }

  // MARK: Internal

  let matrix: SIMD4<Float>
  let fit: SIMD2<Float>
  let offset: SIMD2<Float>
  let frameSize: SIMD2<Float>
  let position: SIMD2<Float>
  let scale: Float
  let rotation: Float
  let opacity: Float
  let padding: Float = 0

}
