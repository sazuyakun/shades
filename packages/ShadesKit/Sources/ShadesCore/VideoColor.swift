/// How a video's colours are encoded, from its file's tags (`nil` where a tag is missing, which
/// plays as Rec.709). The values are CoreVideo's tag names, e.g. "ITU_R_2020" or
/// "ITU_R_2100_HLG". Shades works in Rec.709, so HDR and wide-gamut video is converted.
public struct VideoColor: Hashable, Sendable, Codable {

  // MARK: Lifecycle

  public init(primaries: String?, transfer: String?, matrix: String?) {
    self.primaries = primaries
    self.transfer = transfer
    self.matrix = matrix
  }

  // MARK: Public

  /// The colours red, green and blue stand for: "ITU_R_709_2", "P3_D65", "ITU_R_2020"…
  public let primaries: String?
  /// How values turn into light: "ITU_R_709_2", "ITU_R_2100_HLG", "SMPTE_ST_2084_PQ"…
  public let transfer: String?
  /// How brightness and colour were separated for compression: "ITU_R_709_2", "ITU_R_2020"…
  public let matrix: String?

  /// Whether it's HDR (HLG, as iPhones record it, or PQ), which is tone-mapped to SDR.
  public var isHDR: Bool {
    transfer == "ITU_R_2100_HLG" || transfer == "SMPTE_ST_2084_PQ"
  }

  /// Whether its colours reach past Rec.709's (P3 or Rec.2020), which are brought inside it.
  public var isWideGamut: Bool {
    primaries.map { ["P3_D65", "DCI_P3", "ITU_R_2020"].contains($0) } ?? false
  }

  /// What was converted to show it in Rec.709, in plain words, or `nil` when nothing was.
  public var conversion: String? {
    let gamut =
      switch primaries {
      case "ITU_R_2020": "Rec.2020"
      case "P3_D65",
           "DCI_P3": "P3"
      default: nil as String?
      }
    if isHDR {
      let kind = transfer == "ITU_R_2100_HLG" ? "HLG" : "PQ"
      return "HDR (\(kind)\(gamut.map { ", \($0)" } ?? "")) tone-mapped to Rec.709"
    }
    return gamut.map { "Wide colour (\($0)) converted to Rec.709" }
  }

}
