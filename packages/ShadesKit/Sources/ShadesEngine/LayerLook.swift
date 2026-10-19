import CoreGraphics
import ShadesCore

/// What the shader needs to key, grade, add effects to and blend one layer. Its memory layout
/// must match `LayerLook` in Shaders/Layers.metal.
struct LayerLook {

  // MARK: Lifecycle

  /// The look of a layer whose source is `size` pixels: its grade, effects and blend, whether
  /// it's masked by the subject or an adjustment clip, a `seed` that changes each frame, and how
  /// a transition it's part of shapes it.
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
    transition: TransitionStyle?,
    clipTime: Double,
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
    dip = Float(transition?.dip ?? 0)
    wipeProgress = Float(transition?.wipeProgress ?? 0)
    dipToWhite = transition?.dipsToWhite == true ? 1 : 0
    let qualifier = grade.qualifier
    qualifierHue = Float(qualifier?.hue ?? 0)
    qualifierHueWidth = Float(qualifier?.hueWidth ?? 0)
    qualifierSaturation = Float(qualifier?.minSaturation ?? 0)
    qualifierLow = Float(qualifier?.brightness.first ?? 0)
    qualifierHigh = Float(qualifier?.brightness.last ?? 1)
    qualifierSoftness = Float(qualifier?.softness ?? 0)
    let window = grade.window
    windowX = Float(window?.x ?? 0.5)
    windowY = Float(window?.y ?? 0.5)
    windowWidth = Float(window?.width ?? 1)
    windowHeight = Float(window?.height ?? 1)
    windowSoftness = Float(window?.softness ?? 0)
    hasQualifier = qualifier == nil ? 0 : 1
    hasWindow = window == nil ? 0 : 1
    windowIsEllipse = window?.isEllipse == false ? 0 : 1
    windowInverted = window?.inverted == true ? 1 : 0
    effectTime = Float(clipTime)
    effectAmount = Float(effects.shaderAmount)
    wipe =
      switch transition?.wipe {
      case .slices: 1
      case .tiles: 2
      case .iris: 3
      default: 0
      }
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
  let dip: Float
  let wipeProgress: Float
  let dipToWhite: Int32
  let wipe: Int32
  let effectTime: Float
  let effectAmount: Float
  let qualifierHue: Float
  let qualifierHueWidth: Float
  let qualifierSaturation: Float
  let qualifierLow: Float
  let qualifierHigh: Float
  let qualifierSoftness: Float
  let windowX: Float
  let windowY: Float
  let windowWidth: Float
  let windowHeight: Float
  let windowSoftness: Float
  let hasQualifier: Int32
  let hasWindow: Int32
  let windowIsEllipse: Int32
  let windowInverted: Int32

}
