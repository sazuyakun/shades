import AVFoundation

/// The colour tags a test video is written with. Its pixels are stored as given, so a value of
/// 191 in an HLG video means HLG's 75% (reference white), not an SDR colour converted to HLG.
public enum FixtureColorSpace: Sendable {
  /// SDR, what Shades works in.
  case rec709
  /// HDR as iPhones record it (and Dolby Vision's base layer): HLG in Rec.2020.
  case hlg
  /// HDR10: PQ in Rec.2020.
  case pq
  /// Wide-colour SDR: P3 primaries, Rec.709 transfer.
  case displayP3

  // MARK: Internal

  /// The tags for `AVVideoColorPropertiesKey`.
  var properties: [String: String] {
    switch self {
    case .rec709:
      [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
      ]

    case .hlg:
      [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
      ]

    case .pq:
      [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_SMPTE_ST_2084_PQ,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
      ]

    case .displayP3:
      [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
      ]
    }
  }
}
