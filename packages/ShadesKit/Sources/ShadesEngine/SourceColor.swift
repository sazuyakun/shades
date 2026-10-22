import CoreVideo

/// How a video frame's values turn into colour, read from the frame's tags: its transfer (SDR,
/// or HDR to tone-map) and its primaries (Rec.709, or a wider gamut to bring inside it). The
/// layer shader converts anything that isn't SDR Rec.709. AVFoundation usually hands frames
/// over in Rec.709 primaries already, but not on every Mac, so the tags decide. Raw values match
/// `transfer` and `primaries` in Shaders/Layers.metal; tags are CoreVideo's names.
struct SourceColor: Equatable {

  // MARK: Lifecycle

  init(of frame: CVPixelBuffer) {
    let tag = { (key: CFString) in CVBufferCopyAttachment(frame, key, nil) as? String }
    transfer =
      switch tag(kCVImageBufferTransferFunctionKey) {
      case "ITU_R_2100_HLG": .hlg
      case "SMPTE_ST_2084_PQ": .pq
      default: .sdr
      }
    primaries =
      switch tag(kCVImageBufferColorPrimariesKey) {
      case "P3_D65",
           "DCI_P3": .p3
      case "ITU_R_2020": .rec2020
      default: .rec709
      }
  }

  // MARK: Internal

  /// How values turn into light.
  enum Transfer: Int32 {
    case sdr
    /// Hybrid log-gamma, as iPhones record HDR (Dolby Vision's base layer too).
    case hlg
    /// Perceptual quantizer (HDR10).
    case pq
  }

  /// Which red, green and blue the values mean.
  enum Primaries: Int32 {
    case rec709
    case p3
    case rec2020
  }

  let transfer: Transfer
  let primaries: Primaries

}
