import CoreGraphics

/// The values the shader needs to draw one frame upright and fitted. Its memory layout must
/// match `FrameUniforms` in Shaders/Passthrough.metal.
struct FrameUniforms {

  // MARK: Lifecycle

  /// Works out how to draw a stored frame of `stored` size, tagged with `transform` (its
  /// rotation), into an output of `output` size.
  init(stored: CGSize, transform: CGAffineTransform, output: CGSize) {
    let upright = CGRect(origin: .zero, size: stored).applying(transform)
    let uprightToStored = CGAffineTransform(scaleX: upright.width, y: upright.height)
      .translatedBy(x: upright.minX / upright.width, y: upright.minY / upright.height)
      .concatenating(transform.inverted())
      .concatenating(CGAffineTransform(scaleX: 1 / stored.width, y: 1 / stored.height))
    let uprightAspect = upright.width / upright.height
    let outputAspect = output.width / output.height
    scale = uprightAspect > outputAspect
      ? SIMD2(1, Float(outputAspect / uprightAspect))
      : SIMD2(Float(uprightAspect / outputAspect), 1)
    offset = SIMD2(Float(uprightToStored.tx), Float(uprightToStored.ty))
    matrix = SIMD4(
      Float(uprightToStored.a),
      Float(uprightToStored.b),
      Float(uprightToStored.c),
      Float(uprightToStored.d),
    )
  }

  // MARK: Internal

  let scale: SIMD2<Float>
  let offset: SIMD2<Float>
  let matrix: SIMD4<Float>

}
