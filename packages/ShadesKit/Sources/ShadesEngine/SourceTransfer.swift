import CoreVideo

/// How a video frame's values turn into light, read from the frame's colour tag: SDR (Rec.709,
/// drawn as is) or HDR, which the layer shader tone-maps into the Rec.709 working space. Its
/// raw values match `transfer` in Shaders/Layers.metal.
enum SourceTransfer: Int32 {
  case sdr
  /// Hybrid log-gamma, as iPhones record HDR (Dolby Vision's base layer too).
  case hlg
  /// Perceptual quantizer (HDR10).
  case pq

  // MARK: Lifecycle

  init(of frame: CVPixelBuffer) {
    let tag = CVBufferCopyAttachment(frame, kCVImageBufferTransferFunctionKey, nil) as? String
    if tag == kCVImageBufferTransferFunction_ITU_R_2100_HLG as String {
      self = .hlg
    } else if tag == kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String {
      self = .pq
    } else {
      self = .sdr
    }
  }
}
