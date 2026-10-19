import AVFoundation

/// How exported video is compressed.
public enum VideoCodec: String, CaseIterable, Codable, Sendable {
  /// HEVC (H.265): smaller files at the same quality; YouTube and Instagram take it.
  case hevc
  /// H.264: plays everywhere.
  case h264

  // MARK: Internal

  /// The export preset: the highest quality, at the composition's own size.
  var preset: String {
    switch self {
    case .hevc: AVAssetExportPresetHEVCHighestQuality
    case .h264: AVAssetExportPresetHighestQuality
    }
  }
}
