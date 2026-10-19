import CoreGraphics
import ShadesCore

/// What the shader needs to key, grade, add effects to and blend one layer. Its memory layout
/// must match `LayerLook` in Shaders/Layers.metal.
struct LayerLook {

  // MARK: Lifecycle

  /// The look of a layer whose source is `size` pixels: its grade, effects and blend, whether
  /// it's masked by the subject or an adjustment clip, and a `seed` that changes each frame.
  init(
    size: CGSize,
    grade: Grade?,
    effects: Effects?,
    blend: BlendMode,
    isMasked: Bool,
    isAdjustment: Bool,
    hasLUT: Bool,
    hasCurves: Bool,
    seed: Double,
  ) {
    let grade = grade ?? Grade()
    let effects = effects ?? Effects()
    texel = SIMD2(Float(1 / max(size.width, 1)), Float(1 / max(size.height, 1)))
    exposure = Float(grade.exposure)
    contrast = Float(grade.contrast)
    saturation = Float(grade.saturation)
    temperature = Float(grade.temperature)
    tint = Float(grade.tint)
    lift = Float(grade.lift)
    gamma = Float(grade.gamma)
    gain = Float(grade.gain)
    lutAmount = hasLUT ? Float(grade.lutAmount) : 0
    grain = Float(effects.grain)
    vignette = Float(effects.vignette)
    halation = Float(effects.halation)
    blur = Float(effects.blur)
    keyRed = Float(effects.key?.color.red ?? 0)
    keyGreen = Float(effects.key?.color.green ?? 0)
    keyBlue = Float(effects.key?.color.blue ?? 0)
    keyTolerance = Float(effects.key?.tolerance ?? 0)
    keySoftness = Float(effects.key?.softness ?? 0)
    self.seed = Float(seed.truncatingRemainder(dividingBy: 1000))
    self.blend = Int32(BlendMode.allCases.firstIndex(of: blend) ?? 0)
    masked = isMasked ? 1 : 0
    self.hasCurves = hasCurves ? 1 : 0
    self.isAdjustment = isAdjustment ? 1 : 0
  }

  // MARK: Internal

  let texel: SIMD2<Float>
  let exposure: Float
  let contrast: Float
  let saturation: Float
  let temperature: Float
  let tint: Float
  let lift: Float
  let gamma: Float
  let gain: Float
  let lutAmount: Float
  let grain: Float
  let vignette: Float
  let halation: Float
  let blur: Float
  let keyRed: Float
  let keyGreen: Float
  let keyBlue: Float
  let keyTolerance: Float
  let keySoftness: Float
  let seed: Float
  let blend: Int32
  let masked: Int32
  let hasCurves: Int32
  let isAdjustment: Int32

}
