/// Where a video is going, and how loud that platform plays it.
public enum LoudnessTarget: String, CaseIterable, Codable, Sendable {
  case youtube
  case instagram
  case tiktok
  case podcast
  case broadcast

  // MARK: Public

  /// The integrated loudness to aim for, in LUFS.
  public var lufs: Double {
    switch self {
    case .youtube,
         .instagram,
         .tiktok: -14
    case .podcast: -16
    case .broadcast: -23
    }
  }

  /// The platform's name, for menus.
  public var title: String {
    switch self {
    case .youtube: "YouTube"
    case .instagram: "Instagram & Reels"
    case .tiktok: "TikTok"
    case .podcast: "Podcast"
    case .broadcast: "Broadcast (EBU R128)"
    }
  }
}
