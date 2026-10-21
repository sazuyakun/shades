import ShadesEngine

/// How preview quality reads in the viewer's menu and the command palette.
extension PreviewQuality {
  var title: String {
    switch self {
    case .auto: "Auto"
    case .full: "Full"
    case .half: "Half"
    }
  }

  /// The next quality, for the shortcut that steps through them.
  var next: PreviewQuality {
    switch self {
    case .auto: .full
    case .full: .half
    case .half: .auto
    }
  }
}
